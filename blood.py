import datetime

import matplotlib.pyplot as plt
import mysql.connector
import pandas as pd
import streamlit as st

# ------------------------------------------------------------
# 1. DATABASE CONNECTION
# Change the password if yours is different.
# ------------------------------------------------------------
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "1234",
    "database": "blood_db",
}


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


def run_query(sql, params=None):
    """Runs a SELECT and returns a list of dictionaries."""
    conn = get_connection()
    cur = conn.cursor(dictionary=True)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


def run_write(sql, params=None):
    """Runs an INSERT / UPDATE. Database errors (including trigger errors) bubble up."""
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(sql, params or ())
        conn.commit()
    finally:
        cur.close()
        conn.close()


def call_find_eligible_donors(request_id):
    """Calls the stored procedure and returns a DataFrame."""
    conn = get_connection()
    cur = conn.cursor()
    cur.callproc("find_eligible_donors", (request_id,))
    df = pd.DataFrame()
    for result in cur.stored_results():
        df = pd.DataFrame(result.fetchall(), columns=result.column_names)
    cur.close()
    conn.close()
    return df


# ------------------------------------------------------------
# 2. SMALL HELPERS FOR DROPDOWNS
# ------------------------------------------------------------
def blood_group_list():
    return [r["blood_group"] for r in run_query("SELECT blood_group FROM blood_groups")]


def hospital_map():
    rows = run_query("SELECT hospital_id, name, city FROM hospitals")
    return {f"{r['name']} ({r['city']})": r["hospital_id"] for r in rows}


def open_request_map():
    rows = run_query("SELECT request_id, patient_name, blood_group, hospital FROM v_open_requests")
    return {
        f"#{r['request_id']}: {r['patient_name']} needs {r['blood_group']} at {r['hospital']}": r["request_id"]
        for r in rows
    }


# ------------------------------------------------------------
# 3. PAGES
# ------------------------------------------------------------
def home_page():
    st.title("🩸 Blood Donation Matching System")
    st.write("Register donors, post emergency requests, and find the right donors fast.")

    donors = run_query("SELECT COUNT(*) AS c FROM donors")[0]["c"]
    open_reqs = run_query("SELECT COUNT(*) AS c FROM blood_requests WHERE status = 'Open'")[0]["c"]
    units = run_query("SELECT COALESCE(SUM(units_available), 0) AS c FROM blood_stock")[0]["c"]

    c1, c2, c3 = st.columns(3)
    c1.metric("Registered donors", donors)
    c2.metric("Open requests", open_reqs)
    c3.metric("Units in stock", int(units))

    st.info("Use the menu on the left to get started.")


def register_donor_page():
    st.header("📝 Register a Donor")

    with st.form("donor_form"):
        name = st.text_input("Full name")
        gender = st.selectbox("Gender", ["M", "F", "Other"])
        dob = st.date_input(
            "Date of birth",
            value=datetime.date(2000, 1, 1),
            min_value=datetime.date(1950, 1, 1),
            max_value=datetime.date.today(),
        )
        blood_group = st.selectbox("Blood group", blood_group_list())
        phone = st.text_input("Phone")
        city = st.text_input("City")
        weight = st.number_input("Weight (kg)", min_value=30.0, max_value=200.0, value=60.0)
        submitted = st.form_submit_button("Register")

    if submitted:
        age = (datetime.date.today() - dob).days // 365
        if not (name and phone and city):
            st.warning("Please fill in name, phone and city.")
        elif age < 18:
            st.error("Donors must be at least 18 years old.")
        else:
            try:
                run_write(
                    "INSERT INTO donors (name, gender, dob, blood_group, phone, city, weight_kg) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                    (name, gender, dob, blood_group, phone, city, weight),
                )
                st.success(f"{name} has been registered as a donor. Thank you!")
            except mysql.connector.Error as e:
                st.error(f"Could not register: {e.msg}")


def post_request_page():
    st.header("🚨 Post a Blood Request")

    hospitals = hospital_map()
    with st.form("request_form"):
        hospital = st.selectbox("Hospital", list(hospitals.keys()))
        patient = st.text_input("Patient name")
        blood_group = st.selectbox("Blood group needed", blood_group_list())
        units = st.number_input("Units needed", min_value=1, max_value=10, value=1)
        urgency = st.selectbox("Urgency", ["Critical", "Urgent", "Normal"])
        submitted = st.form_submit_button("Post request")

    if submitted:
        if not patient:
            st.warning("Please enter the patient's name.")
        else:
            try:
                run_write(
                    "INSERT INTO blood_requests "
                    "(hospital_id, patient_name, blood_group, units_needed, urgency, request_date) "
                    "VALUES (%s, %s, %s, %s, %s, CURDATE())",
                    (hospitals[hospital], patient, blood_group, units, urgency),
                )
                st.success("Request posted. Go to 'Find Donors' to match donors.")
            except mysql.connector.Error as e:
                st.error(f"Could not post request: {e.msg}")


def find_donors_page():
    st.header("🔍 Find Eligible Donors")

    requests = open_request_map()
    if not requests:
        st.info("There are no open requests right now.")
        return

    choice = st.selectbox("Choose an open request", list(requests.keys()))
    request_id = requests[choice]

    if st.button("Find donors"):
        df = call_find_eligible_donors(request_id)
        if df.empty:
            st.warning("No eligible donors found in this city right now.")
        else:
            st.success(f"{len(df)} eligible donor(s) found. Exact blood group matches are listed first.")
            st.dataframe(df, use_container_width=True)


def record_donation_page():
    st.header("💉 Record a Donation")

    donors = run_query("SELECT donor_id, name, blood_group FROM donors")
    donor_map = {f"{d['name']} ({d['blood_group']})": d["donor_id"] for d in donors}
    hospitals = hospital_map()
    requests = open_request_map()
    request_options = ["None (regular donation)"] + list(requests.keys())

    with st.form("donation_form"):
        donor = st.selectbox("Donor", list(donor_map.keys()))
        hospital = st.selectbox("Hospital", list(hospitals.keys()))
        request = st.selectbox("For which request?", request_options)
        units = st.number_input("Units", min_value=1, max_value=2, value=1)
        date = st.date_input("Donation date", value=datetime.date.today())
        submitted = st.form_submit_button("Record donation")

    if submitted:
        request_id = requests.get(request)  # None if "None (regular donation)"
        try:
            run_write(
                "INSERT INTO donations (donor_id, hospital_id, request_id, donation_date, units) "
                "VALUES (%s, %s, %s, %s, %s)",
                (donor_map[donor], hospitals[hospital], request_id, date, units),
            )
            st.success("Donation recorded. Stock and the donor's last donation date were updated by the trigger.")
        except mysql.connector.Error as e:
            # The trigger's SIGNAL message shows up here
            st.error(f"Donation rejected: {e.msg}")


def stock_requests_page():
    st.header("📦 Stock and Requests")

    st.subheader("Total stock by blood group")
    st.dataframe(pd.DataFrame(run_query("SELECT * FROM v_stock_summary")), use_container_width=True)

    st.subheader("Stock by hospital")
    rows = run_query(
        """
        SELECT h.name AS hospital, bs.blood_group, bs.units_available
        FROM blood_stock bs
        JOIN hospitals h ON bs.hospital_id = h.hospital_id
        ORDER BY h.name, bs.blood_group
        """
    )
    st.dataframe(pd.DataFrame(rows), use_container_width=True)

    st.subheader("Open requests (most urgent first)")
    open_rows = run_query("SELECT * FROM v_open_requests")
    if open_rows:
        st.dataframe(pd.DataFrame(open_rows), use_container_width=True)

        st.subheader("Mark a request as fulfilled")
        requests = open_request_map()
        choice = st.selectbox("Request", list(requests.keys()))
        if st.button("Mark as fulfilled"):
            run_write("UPDATE blood_requests SET status = 'Fulfilled' WHERE request_id = %s", (requests[choice],))
            st.success("Request marked as fulfilled.")
            st.rerun()
    else:
        st.info("No open requests.")


def dashboard_page():
    st.header("📊 Dashboard")

    # Chart 1: stock per blood group
    stock = pd.DataFrame(run_query("SELECT blood_group, total_units FROM v_stock_summary"))
    if not stock.empty:
        stock["total_units"] = stock["total_units"].astype(float)
        fig, ax = plt.subplots()
        ax.bar(stock["blood_group"], stock["total_units"], color="crimson")
        ax.set_title("Blood Stock by Group")
        ax.set_xlabel("Blood group")
        ax.set_ylabel("Units available")
        st.pyplot(fig)

    # Chart 2: donors per blood group
    donors = pd.DataFrame(
        run_query("SELECT blood_group, COUNT(*) AS total FROM donors GROUP BY blood_group ORDER BY total DESC")
    )
    if not donors.empty:
        fig, ax = plt.subplots()
        ax.bar(donors["blood_group"], donors["total"], color="steelblue")
        ax.set_title("Registered Donors by Blood Group")
        ax.set_xlabel("Blood group")
        ax.set_ylabel("Number of donors")
        st.pyplot(fig)

    # Chart 3: units received per hospital
    hosp = pd.DataFrame(
        run_query(
            """
            SELECT h.name, SUM(d.units) AS units_received
            FROM hospitals h
            JOIN donations d ON h.hospital_id = d.hospital_id
            GROUP BY h.hospital_id, h.name
            """
        )
    )
    if not hosp.empty:
        hosp["units_received"] = hosp["units_received"].astype(float)
        fig, ax = plt.subplots()
        ax.barh(hosp["name"], hosp["units_received"], color="seagreen")
        ax.set_title("Units Donated per Hospital")
        ax.set_xlabel("Units")
        st.pyplot(fig)


# ------------------------------------------------------------
# 4. SIDEBAR MENU
# ------------------------------------------------------------
st.set_page_config(page_title="Blood Donation System", page_icon="🩸")

page = st.sidebar.radio(
    "Menu",
    [
        "Home",
        "Register Donor",
        "Post Request",
        "Find Donors",
        "Record Donation",
        "Stock and Requests",
        "Dashboard",
    ],
)

try:
    if page == "Home":
        home_page()
    elif page == "Register Donor":
        register_donor_page()
    elif page == "Post Request":
        post_request_page()
    elif page == "Find Donors":
        find_donors_page()
    elif page == "Record Donation":
        record_donation_page()
    elif page == "Stock and Requests":
        stock_requests_page()
    elif page == "Dashboard":
        dashboard_page()
except mysql.connector.Error as err:
    st.error(f"Database error: {err}")
    st.write("Check that MySQL is running and the password in DB_CONFIG is correct.")