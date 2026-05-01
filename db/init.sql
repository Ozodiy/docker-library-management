-- Library Management System – database schema and seed data

CREATE TABLE IF NOT EXISTS books (
    id         SERIAL PRIMARY KEY,
    title      VARCHAR(255) NOT NULL,
    author     VARCHAR(255) NOT NULL,
    isbn       VARCHAR(20)  DEFAULT '',
    available  BOOLEAN      DEFAULT TRUE,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS loans (
    id        SERIAL PRIMARY KEY,
    book_id   INTEGER REFERENCES books(id) ON DELETE CASCADE,
    user_id   INTEGER REFERENCES users(id) ON DELETE CASCADE,
    loan_date DATE    NOT NULL,
    due_date  DATE    NOT NULL,
    returned  BOOLEAN DEFAULT FALSE
);

-- Indexes for frequent queries
CREATE INDEX IF NOT EXISTS idx_loans_book   ON loans(book_id);
CREATE INDEX IF NOT EXISTS idx_loans_user   ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_due    ON loans(due_date) WHERE returned = FALSE;
CREATE INDEX IF NOT EXISTS idx_books_avail  ON books(available);

-- Sample books
INSERT INTO books (title, author, isbn) VALUES
    ('The Pragmatic Programmer',  'David Thomas & Andrew Hunt', '978-0135957059'),
    ('Clean Code',                'Robert C. Martin',           '978-0132350884'),
    ('Docker Deep Dive',          'Nigel Poulton',              '978-1521822807'),
    ('Python Crash Course',       'Eric Matthes',               '978-1718502703'),
    ('The Linux Command Line',    'William Shotts',             '978-1593279523'),
    ('Designing Data-Intensive Applications', 'Martin Kleppmann', '978-1449373320'),
    ('Site Reliability Engineering', 'Beyer, Jones, Petoff',   '978-1491929124');

-- Sample users
INSERT INTO users (name, email) VALUES
    ('Alice Kowalski',   'alice@example.com'),
    ('Bob Nowak',        'bob@example.com'),
    ('Carol Wisniewska', 'carol@example.com');

-- Sample loan (already returned)
INSERT INTO loans (book_id, user_id, loan_date, due_date, returned) VALUES
    (1, 1, CURRENT_DATE - INTERVAL '20 days', CURRENT_DATE - INTERVAL '6 days', TRUE);

-- Sample active loan (overdue by a few days)
INSERT INTO loans (book_id, user_id, loan_date, due_date, returned) VALUES
    (2, 2, CURRENT_DATE - INTERVAL '18 days', CURRENT_DATE - INTERVAL '4 days', FALSE);

UPDATE books SET available = FALSE WHERE id = 2;
