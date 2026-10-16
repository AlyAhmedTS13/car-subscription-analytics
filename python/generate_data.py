"""Generate synthetic car-subscription data (Saudi Arabia, 2025) as CSVs in data/.

Pipeline:
  1. cars            - fixed catalogue with jittered base prices
  2. visitors        - daily Poisson traffic with monthly seasonality, channel/city mix, A/B assignment
  3. conversion      - visitor -> customer by channel x city x A/B factor
  4. subscriptions   - per-customer event simulation (cancel / renew / leave / return) up to the cutoff
  5. payments        - one per due month, status by customer risk profile
  6. quality issues  - injected after the clean data is built
"""

import calendar
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

rng = np.random.default_rng(42)

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
START, CUTOFF = date(2025, 1, 1), date(2025, 12, 31)
AB_START, AB_END = date(2025, 10, 6), date(2025, 11, 30)
AVG_VISITORS_PER_DAY = 500

CHANNELS = {"organic": 0.35, "paid_search": 0.30, "social": 0.25, "referral": 0.10}
CITIES = {"Riyadh": 0.50, "Jeddah": 0.30, "Dammam": 0.20}
CONVERSION = {"referral": 0.15, "organic": 0.11, "paid_search": 0.09, "social": 0.06}
CITY_CONV_FACTOR = {"Riyadh": 1.0, "Jeddah": 1.0, "Dammam": 0.9}
MONTH_VOLUME = {1: 1.25, 6: 0.90, 7: 0.90, 8: 0.90, 9: 1.30}
SUMMER = {6, 7, 8}

SEGMENTS = {"economy": 0.55, "suv": 0.30, "luxury": 0.15}
SEGMENT_BASE = {"economy": 2400, "suv": 3800, "luxury": 6500}
PLANS = [1, 3, 6, 12]
PLAN_DISCOUNT = {1: 0.00, 3: 0.08, 6: 0.15, 12: 0.25}
PLAN_MIX = [0.45, 0.20, 0.20, 0.15]
PLAN_MIX_TREATMENT = [0.37, 0.20, 0.25, 0.18]
RENEW_PROB = {1: 0.70, 3: 0.75, 6: 0.80, 12: 0.85}
CANCEL_MONTHLY = {1: 0.0, 3: 0.02, 6: 0.015, 12: 0.01}

RISK_SHARE = 0.10
PAY_STATUS = ["paid", "late", "failed"]
PAY_PROBS = {False: [0.92, 0.05, 0.03], True: [0.70, 0.10, 0.20]}
RETURN_PROB = {False: 0.20, True: 0.10}

CAR_MODELS = [
    ("Toyota Yaris", "economy"), ("Hyundai Accent", "economy"), ("Kia Pegas", "economy"),
    ("Nissan Sunny", "economy"), ("Toyota Corolla", "economy"), ("Hyundai Elantra", "economy"),
    ("Kia Cerato", "economy"),
    ("Hyundai Tucson", "suv"), ("Toyota RAV4", "suv"), ("Kia Sportage", "suv"),
    ("Nissan X-Trail", "suv"), ("Toyota Fortuner", "suv"),
    ("Lexus ES", "luxury"), ("Mercedes-Benz E-Class", "luxury"), ("BMW 5 Series", "luxury"),
]


def add_months(d: date, n: int) -> date:
    y, m = divmod(d.month - 1 + n, 12)
    y, m = d.year + y, m + 1
    return date(y, m, min(d.day, calendar.monthrange(y, m)[1]))


# ---------------------------------------------------------------- cars
cars = pd.DataFrame(CAR_MODELS, columns=["model", "segment"])
cars.insert(0, "car_id", np.arange(1, len(cars) + 1))
cars["base_monthly_price"] = (
    cars["segment"].map(SEGMENT_BASE) * rng.uniform(0.9, 1.1, len(cars)) / 10
).round() * 10
cars_by_segment = {s: g["car_id"].to_numpy() for s, g in cars.groupby("segment")}
car_price = dict(zip(cars["car_id"], cars["base_monthly_price"]))

# ---------------------------------------------------------------- visitors
days = pd.date_range(START, CUTOFF, freq="D")
mult = days.month.map(lambda m: MONTH_VOLUME.get(m, 1.0)).to_numpy()
mult = mult / mult.mean()  # keep the yearly average at ~500/day
daily_counts = rng.poisson(AVG_VISITORS_PER_DAY * mult)

n_vis = int(daily_counts.sum())
visit_date = np.repeat(days.date, daily_counts)
visitors = pd.DataFrame({
    "visitor_id": np.arange(1, n_vis + 1),
    "visit_date": visit_date,
    "channel": rng.choice(list(CHANNELS), n_vis, p=list(CHANNELS.values())),
    "city": rng.choice(list(CITIES), n_vis, p=list(CITIES.values())),
})
in_window = (visitors["visit_date"] >= AB_START) & (visitors["visit_date"] <= AB_END)
visitors["ab_group"] = pd.Series(pd.NA, index=visitors.index, dtype="string")
visitors.loc[in_window, "ab_group"] = rng.choice(["control", "treatment"], int(in_window.sum()))
is_treat = (visitors["ab_group"] == "treatment").fillna(False).to_numpy()

# ---------------------------------------------------------------- conversion
p_conv = (
    visitors["channel"].map(CONVERSION).to_numpy()
    * visitors["city"].map(CITY_CONV_FACTOR).to_numpy()
    * np.where(is_treat, 0.95, 1.0)
)
converted = rng.random(n_vis) < p_conv
n_cust = int(converted.sum())
visitors["customer_id"] = pd.Series(pd.NA, index=visitors.index, dtype="Int64")
visitors.loc[converted, "customer_id"] = np.arange(1, n_cust + 1)

customers = pd.DataFrame({
    "customer_id": np.arange(1, n_cust + 1),
    "signup_date": visitors.loc[converted, "visit_date"].to_numpy(),
})
cust_risk = rng.random(n_cust) < RISK_SHARE
cust_treat = is_treat[converted]

# ---------------------------------------------------------------- subscriptions + payments
seg_names, seg_probs = list(SEGMENTS), list(SEGMENTS.values())
sub_rows, pay_rows = [], []


def pick_car_and_plan(treatment: bool):
    seg = rng.choice(seg_names, p=seg_probs)
    car = int(rng.choice(cars_by_segment[seg]))
    plan = int(rng.choice(PLANS, p=PLAN_MIX_TREATMENT if treatment else PLAN_MIX))
    price = car_price[car] * (1 - PLAN_DISCOUNT[plan])
    if treatment and plan == 1:
        price *= 1.20
    return car, plan, round(price, 2)


for cid, risk, treat, start in zip(
    customers["customer_id"], cust_risk, cust_treat, customers["signup_date"]
):
    risk_mult = 2.0 if risk else 1.0
    car, plan, price = pick_car_and_plan(treat)
    in_test_chain = treat  # renewals inherit the treatment experience; returns are baseline

    while True:
        sub_id = len(sub_rows) + 1
        cancel_p = CANCEL_MONTHLY[plan] * risk_mult
        if in_test_chain and plan in (6, 12):
            cancel_p *= 1.4

        end, status = None, "active"
        for k in range(plan):
            due = add_months(start, k)
            if due > CUTOFF:
                break
            pay_status = rng.choice(PAY_STATUS, p=PAY_PROBS[bool(risk)])
            pay_rows.append((sub_id, due, price, pay_status))
            p = cancel_p * (1.5 if due.month in SUMMER else 1.0)
            if rng.random() < p:
                cancel_date = due + timedelta(days=int(rng.integers(1, 28)))
                if cancel_date <= CUTOFF:
                    end, status = cancel_date, "cancelled"
                break
        else:
            term_end = add_months(start, plan)
            if term_end <= CUTOFF:
                end, status = term_end, "completed"

        sub_rows.append((sub_id, cid, car, plan, price, start, end, status))
        if status == "active":
            break

        if status == "completed":
            leave_p = (1 - RENEW_PROB[plan]) * risk_mult * (1.5 if end.month in SUMMER else 1.0)
            if rng.random() >= min(leave_p, 1.0):
                start = end  # renewal: same car, plan and price
                continue

        # customer left (completed without renewal, or cancelled): maybe return later
        if rng.random() < RETURN_PROB[bool(risk)]:
            ret = end + timedelta(days=int(rng.integers(30, 122)))
            if ret <= CUTOFF:
                start = ret
                car, plan, price = pick_car_and_plan(False)
                in_test_chain = False
                continue
        break

subscriptions = pd.DataFrame(sub_rows, columns=[
    "subscription_id", "customer_id", "car_id", "plan_months", "monthly_price",
    "start_date", "end_date", "status",
])
payments = pd.DataFrame(pay_rows, columns=["subscription_id", "due_date", "amount", "status"])
payments.insert(0, "payment_id", np.arange(1, len(payments) + 1))

# ---------------------------------------------------------------- data-quality injection
# visitors: empty city / messy channel spelling (disjoint rows)
idx = rng.permutation(n_vis)
n1 = int(n_vis * 0.01)
visitors["city"] = visitors["city"].astype("string")
visitors.loc[idx[:n1], "city"] = pd.NA
channel_variants = {
    "organic": ["Organic", "organic ", "Organic ", "ORGANIC"],
    "paid_search": ["Paid_Search", "paid search", "Paid Search", "paid-search"],
    "social": ["Social", "social ", "SOCIAL"],
    "referral": ["Referral", "referal", "Referral "],
}
messy = idx[n1:2 * n1]
visitors.loc[messy, "channel"] = [
    rng.choice(channel_variants[c]) for c in visitors.loc[messy, "channel"]
]

# subscriptions: end_date before start_date
ended = subscriptions.index[subscriptions["end_date"].notna()]
bad = rng.choice(ended, 15, replace=False)
subscriptions["end_date"] = subscriptions["end_date"].astype(object)
subscriptions.loc[bad, "end_date"] = [
    s - timedelta(days=int(rng.integers(1, 31))) for s in subscriptions.loc[bad, "start_date"]
]

# payments: zero amounts, orphan subscription_ids, exact duplicates
pidx = rng.permutation(len(payments))
payments.loc[pidx[:10], "amount"] = 0.0
orphans = payments.iloc[pidx[10:30]].copy()
orphans["payment_id"] = np.arange(len(payments) + 1, len(payments) + 21)
orphans["subscription_id"] = rng.choice(
    np.arange(len(subscriptions) + 1, len(subscriptions) + 5000), 20, replace=False
)
dupes = payments.iloc[pidx[30:70]]
payments = (
    pd.concat([payments, orphans, dupes])
    .sort_values("payment_id", kind="stable")
    .reset_index(drop=True)
)

# ---------------------------------------------------------------- write
DATA_DIR.mkdir(exist_ok=True)
outputs = {
    "visitors": visitors,
    "customers": customers,
    "cars": cars,
    "subscriptions": subscriptions,
    "payments": payments,
}
for name, df in outputs.items():
    df.to_csv(DATA_DIR / f"{name}.csv", index=False, na_rep="", date_format="%Y-%m-%d",
              float_format="%.2f")

for name, df in outputs.items():
    print(f"{name + '.csv':<20} {len(df):>8,} rows")
print(f"visitors      dates: {visitors['visit_date'].min()} .. {visitors['visit_date'].max()}")
print(f"subscriptions dates: {subscriptions['start_date'].min()} .. "
      f"{subscriptions['start_date'].max()} (start), "
      f"{subscriptions['end_date'].dropna().min()} .. {subscriptions['end_date'].dropna().max()} (end)")
