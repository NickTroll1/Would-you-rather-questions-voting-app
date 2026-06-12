import os
import json
import socket
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, render_template, request, redirect, url_for, session, jsonify

APP_VERSION = os.environ.get("APP_VERSION", "0.1.0")
app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "cloud_computing_survey_secret")

def db_connect():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=3,
    )

def init_db():
    try:
        with db_connect() as conn, conn.cursor() as cur:
            cur.execute('''
                CREATE TABLE IF NOT EXISTS questions (
                    id SERIAL PRIMARY KEY, option_a TEXT NOT NULL, option_b TEXT NOT NULL
                );
            ''')
            cur.execute('''
                CREATE TABLE IF NOT EXISTS votes (
                    id SERIAL PRIMARY KEY, question_id INT NOT NULL, vote CHAR(1) NOT NULL
                );
            ''')
            conn.commit()
            
            cur.execute("SELECT COUNT(*) FROM questions;")
            if cur.fetchone()[0] == 0:
                with open('questions.json', 'r', encoding='utf-8') as f:
                    all_questions = json.load(f)
                    for q in all_questions[:10]:
                        cur.execute("INSERT INTO questions (option_a, option_b) VALUES (%s, %s);", 
                                    (q.get('optionA'), q.get('optionB')))
                conn.commit()
    except Exception as e:
        print(f"Database init failed (might be waiting for DB to start): {e}", flush=True)

init_db()


@app.get("/healthz")
def healthz():
    return jsonify(status="ok"), 200

@app.get("/readyz")
def readyz():

    try:
        with db_connect() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1;")
            cur.fetchone()
        return jsonify(status="ready"), 200
    except Exception as exc:
        return jsonify(status="not-ready", reason=str(exc)[:200]), 503

@app.get("/version")
def version():
    return jsonify(version=APP_VERSION)


@app.get("/")
def index():
    served_by = socket.gethostname()
    
    if 'current_index' not in session:
        session['current_index'] = 0
        
    if session['current_index'] >= 10:
        return render_template('ui.html', finished=True, served_by=served_by, version=APP_VERSION)
        
    try:
        with db_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM questions ORDER BY id;")
            questions = cur.fetchall()
            
        if session['current_index'] >= len(questions):
            return render_template('ui.html', finished=True, served_by=served_by, version=APP_VERSION)
            
        current_question = questions[session['current_index']]
        return render_template('ui.html', q=current_question, finished=False, served_by=served_by, version=APP_VERSION)
        
    except Exception as exc:
        return jsonify(error=str(exc)[:200], served_by=served_by), 500

@app.post("/vote")
def vote():
    question_id = request.form.get('question_id')
    user_vote = request.form.get('vote')
    
    try:
        with db_connect() as conn, conn.cursor() as cur:
            cur.execute("INSERT INTO votes (question_id, vote) VALUES (%s, %s);", (question_id, user_vote))
            conn.commit()
    except Exception as e:
        print(f"Failed to log vote: {e}", flush=True)
        
    session['current_index'] = session.get('current_index', 0) + 1
    return redirect(url_for('index'))

@app.get("/restart")
def restart():
    session['current_index'] = 0
    return redirect(url_for('index'))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
