import os
import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request
from datetime import date, timedelta

app = Flask(__name__)


def get_db():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
    )


# ── Health ────────────────────────────────────────────────────────────────────

@app.route("/health")
def health():
    return jsonify({"status": "ok"})


# ── Books ─────────────────────────────────────────────────────────────────────

@app.route("/books", methods=["GET"])
def list_books():
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM books ORDER BY id")
    books = [dict(r) for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(books)


@app.route("/books/<int:book_id>", methods=["GET"])
def get_book(book_id):
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM books WHERE id = %s", (book_id,))
    book = cur.fetchone()
    cur.close(); conn.close()
    if not book:
        return jsonify({"error": "Book not found"}), 404
    return jsonify(dict(book))


@app.route("/books", methods=["POST"])
def add_book():
    data = request.get_json()
    if not data or not data.get("title") or not data.get("author"):
        return jsonify({"error": "title and author are required"}), 400
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "INSERT INTO books (title, author, isbn) VALUES (%s, %s, %s) RETURNING *",
        (data["title"], data["author"], data.get("isbn", "")),
    )
    book = cur.fetchone()
    conn.commit(); cur.close(); conn.close()
    return jsonify(dict(book)), 201


@app.route("/books/<int:book_id>", methods=["PUT"])
def update_book(book_id):
    data = request.get_json()
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "UPDATE books SET title=%s, author=%s, isbn=%s WHERE id=%s RETURNING *",
        (data["title"], data["author"], data.get("isbn", ""), book_id),
    )
    book = cur.fetchone()
    conn.commit(); cur.close(); conn.close()
    if not book:
        return jsonify({"error": "Book not found"}), 404
    return jsonify(dict(book))


@app.route("/books/<int:book_id>", methods=["DELETE"])
def delete_book(book_id):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM books WHERE id = %s RETURNING id", (book_id,))
    deleted = cur.fetchone()
    conn.commit(); cur.close(); conn.close()
    if not deleted:
        return jsonify({"error": "Book not found"}), 404
    return jsonify({"message": f"Book {book_id} deleted"})


# ── Users ─────────────────────────────────────────────────────────────────────

@app.route("/users", methods=["GET"])
def list_users():
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM users ORDER BY id")
    users = [dict(r) for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(users)


@app.route("/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    user = cur.fetchone()
    cur.close(); conn.close()
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(dict(user))


@app.route("/users", methods=["POST"])
def register_user():
    data = request.get_json()
    if not data or not data.get("name") or not data.get("email"):
        return jsonify({"error": "name and email are required"}), 400
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute(
            "INSERT INTO users (name, email) VALUES (%s, %s) RETURNING *",
            (data["name"], data["email"]),
        )
        user = cur.fetchone()
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        cur.close(); conn.close()
        return jsonify({"error": "Email already registered"}), 409
    cur.close(); conn.close()
    return jsonify(dict(user)), 201


# ── Loans ─────────────────────────────────────────────────────────────────────

@app.route("/loans", methods=["GET"])
def list_loans():
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("""
        SELECT l.id,
               b.title  AS book_title,
               u.name   AS user_name,
               u.email,
               l.loan_date,
               l.due_date,
               l.returned
        FROM loans l
        JOIN books b ON l.book_id = b.id
        JOIN users u ON l.user_id = u.id
        ORDER BY l.id
    """)
    loans = [dict(r) for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(loans)


@app.route("/loans", methods=["POST"])
def create_loan():
    data = request.get_json()
    if not data or not data.get("book_id") or not data.get("user_id"):
        return jsonify({"error": "book_id and user_id are required"}), 400
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT available FROM books WHERE id = %s", (data["book_id"],))
    book = cur.fetchone()
    if not book:
        cur.close(); conn.close()
        return jsonify({"error": "Book not found"}), 404
    if not book["available"]:
        cur.close(); conn.close()
        return jsonify({"error": "Book is not available for loan"}), 400
    today = date.today()
    due = today + timedelta(days=14)
    cur.execute(
        "INSERT INTO loans (book_id, user_id, loan_date, due_date) VALUES (%s,%s,%s,%s) RETURNING *",
        (data["book_id"], data["user_id"], today, due),
    )
    loan = cur.fetchone()
    cur.execute("UPDATE books SET available = FALSE WHERE id = %s", (data["book_id"],))
    conn.commit(); cur.close(); conn.close()
    return jsonify(dict(loan)), 201


@app.route("/loans/<int:loan_id>/return", methods=["POST"])
def return_book(loan_id):
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "UPDATE loans SET returned = TRUE WHERE id = %s AND returned = FALSE RETURNING book_id",
        (loan_id,),
    )
    loan = cur.fetchone()
    if not loan:
        cur.close(); conn.close()
        return jsonify({"error": "Loan not found or already returned"}), 404
    cur.execute("UPDATE books SET available = TRUE WHERE id = %s", (loan["book_id"],))
    conn.commit(); cur.close(); conn.close()
    return jsonify({"message": f"Loan {loan_id} returned successfully"})


@app.route("/loans/overdue", methods=["GET"])
def overdue_loans():
    conn = get_db()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("""
        SELECT l.id,
               b.title        AS book_title,
               u.name         AS user_name,
               u.email,
               l.loan_date,
               l.due_date,
               CURRENT_DATE - l.due_date AS days_overdue
        FROM loans l
        JOIN books b ON l.book_id = b.id
        JOIN users u ON l.user_id = u.id
        WHERE l.due_date < CURRENT_DATE
          AND l.returned = FALSE
        ORDER BY l.due_date
    """)
    loans = [dict(r) for r in cur.fetchall()]
    cur.close(); conn.close()
    return jsonify(loans)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
