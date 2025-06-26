import os
import sys
from flask import Flask, render_template, request, redirect, url_for, session

# 1. Make sure 'scripts' is importable by adding project root to sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from scripts.run_serotyping import run_serotyping
from scripts.run_mlst import run_mlst

# 2. Flask app setup
app = Flask(__name__, template_folder='templates')
app.secret_key = os.environ.get('SECRET_KEY', 'fallback-dev-key')

# 3. Configure uploads folder (absolute path)
UPLOAD_FOLDER = os.path.join(PROJECT_ROOT, 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route('/', methods=['GET', 'POST'])
def index():
    # Clear any old session data on GET
    if request.method == 'GET':
        session.clear()
        return render_template('index.html')

    # POST: handle file upload
    uploaded = request.files.get('file')
    if not uploaded or uploaded.filename == '':
        return redirect(request.url)

    filename = uploaded.filename
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    uploaded.save(filepath)

    # Run ECTyper
    try:
        serotype = run_serotyping(filepath)
    except Exception:
        app.logger.exception("ECTyper failed")
        return "Internal server error (serotyping)", 500

    # Run MLST
    try:
        mlst = run_mlst(filepath)
        try:
            mlst['sequence_type'] = int(mlst.get('sequence_type'))
        except (ValueError, TypeError):
            mlst['sequence_type'] = None
    except Exception:
        app.logger.exception("MLST failed")
        return "Internal server error (MLST)", 500

    # Store in session and redirect to results
    session['filename'] = filename
    session['serotyping_result'] = serotype
    session['mlst_result'] = mlst
    return redirect(url_for('results'))

@app.route('/results')
def results():
    return render_template(
        'index.html',
        filename=session.get('filename'),
        serotyping_result=session.get('serotyping_result'),
        mlst_result=session.get('mlst_result'),
    )

if __name__ == '__main__':
    # Use PORT env var if set (e.g. Render), else default to 5000
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
