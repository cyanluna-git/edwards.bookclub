PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS fiscal_periods (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1))
);

CREATE TABLE IF NOT EXISTS members (
    id INTEGER PRIMARY KEY,
    english_name TEXT NOT NULL,
    korean_name TEXT,
    department TEXT,
    email TEXT,
    member_role TEXT NOT NULL,
    location TEXT,
    active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1)),
    joined_on TEXT,
    bio TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_members_email ON members(email);
CREATE INDEX IF NOT EXISTS idx_members_location ON members(location);
CREATE INDEX IF NOT EXISTS idx_members_role ON members(member_role);

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_digest TEXT,
    role TEXT NOT NULL,
    member_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS reserve_policies (
    id INTEGER PRIMARY KEY,
    member_role TEXT NOT NULL,
    attendance_points INTEGER NOT NULL,
    effective_from TEXT NOT NULL,
    effective_to TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reserve_policies_role_dates
    ON reserve_policies(member_role, effective_from);

CREATE TABLE IF NOT EXISTS meetings (
    id INTEGER PRIMARY KEY,
    legacy_title TEXT,
    title TEXT NOT NULL,
    meeting_at TEXT NOT NULL,
    location TEXT,
    description TEXT,
    review TEXT,
    reserve_exempt_default INTEGER NOT NULL DEFAULT 0 CHECK (reserve_exempt_default IN (0, 1)),
    fiscal_period_id INTEGER,
    created_by INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (fiscal_period_id) REFERENCES fiscal_periods(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_meetings_meeting_at ON meetings(meeting_at);
CREATE INDEX IF NOT EXISTS idx_meetings_location ON meetings(location);

CREATE TABLE IF NOT EXISTS meeting_photos (
    id INTEGER PRIMARY KEY,
    meeting_id INTEGER NOT NULL,
    source_url TEXT,
    file_path TEXT,
    caption TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_meeting_photos_meeting ON meeting_photos(meeting_id);

CREATE TABLE IF NOT EXISTS meeting_attendances (
    id INTEGER PRIMARY KEY,
    meeting_id INTEGER NOT NULL,
    member_id INTEGER NOT NULL,
    reserve_exempt INTEGER NOT NULL DEFAULT 0 CHECK (reserve_exempt IN (0, 1)),
    note TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    UNIQUE (meeting_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_meeting_attendances_member ON meeting_attendances(member_id);

CREATE TABLE IF NOT EXISTS book_requests (
    id INTEGER PRIMARY KEY,
    member_id INTEGER,
    title TEXT NOT NULL,
    author TEXT,
    publisher TEXT,
    price NUMERIC,
    request_status TEXT,
    cover_url TEXT,
    link_url TEXT,
    comment TEXT,
    rating TEXT,
    requested_on TEXT,
    additional_payment NUMERIC,
    fiscal_period_id INTEGER,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL,
    FOREIGN KEY (fiscal_period_id) REFERENCES fiscal_periods(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_book_requests_member ON book_requests(member_id);
CREATE INDEX IF NOT EXISTS idx_book_requests_status ON book_requests(request_status);
CREATE INDEX IF NOT EXISTS idx_book_requests_requested_on ON book_requests(requested_on);

CREATE VIEW IF NOT EXISTS member_reserve_balances AS
WITH attendance_totals AS (
    SELECT
        ma.member_id,
        COALESCE(SUM(rp.attendance_points), 0) AS attendance_reserve_total
    FROM meeting_attendances ma
    JOIN members m ON m.id = ma.member_id
    LEFT JOIN reserve_policies rp
        ON rp.member_role = m.member_role
       AND date(ma.created_at) >= date(rp.effective_from)
       AND (rp.effective_to IS NULL OR date(ma.created_at) <= date(rp.effective_to))
    WHERE ma.reserve_exempt = 0
    GROUP BY ma.member_id
),
book_totals AS (
    SELECT
        br.member_id,
        COALESCE(SUM(br.price), 0) AS purchased_book_total,
        COALESCE(SUM(br.additional_payment), 0) AS additional_payment_total
    FROM book_requests br
    GROUP BY br.member_id
)
SELECT
    m.id AS member_id,
    m.english_name,
    m.korean_name,
    m.member_role,
    m.location,
    COALESCE(at.attendance_reserve_total, 0) AS attendance_reserve_total,
    COALESCE(bt.purchased_book_total, 0) AS purchased_book_total,
    COALESCE(bt.additional_payment_total, 0) AS additional_payment_total,
    COALESCE(at.attendance_reserve_total, 0)
      - COALESCE(bt.purchased_book_total, 0)
      + COALESCE(bt.additional_payment_total, 0) AS balance
FROM members m
LEFT JOIN attendance_totals at ON at.member_id = m.id
LEFT JOIN book_totals bt ON bt.member_id = m.id;
