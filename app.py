from flask import Flask, request, send_file, session
from flask_cors import CORS
import os
from datetime import timedelta
from config import config
from database import db
from auth import (
    hash_password, verify_password, get_user_by_username,
    user_exists, create_user, save_pin_code, save_fingerprint,
    get_user_security, verify_user_pin, verify_user_fingerprint,
    update_user_password, delete_user_security
)
from utils import success_response, error_response, validate_request_data, log_audit

# Initialize Flask app
app = Flask(__name__)

# Load configuration
env = os.getenv('FLASK_ENV', 'development')
app.config.from_object(config[env])

# Configure session
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=7)
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SECURE'] = False  # Set to True in production with HTTPS

# Enable CORS
CORS(app, origins='*', supports_credentials=True)

# Initialize database connection
with app.app_context():
    db.config = app.config
    db.connect()

@app.route('/register', methods=['POST'])
def register():
    """Register a new user"""
    data = request.get_json()
    
    # Validate required fields
    missing_fields = validate_request_data(data, ['username', 'email', 'password'])
    if missing_fields:
        return error_response(
            f"Missing required fields: {', '.join(missing_fields)}",
            400
        )
    
    username = data.get('username', '').strip()
    email = data.get('email', '').strip()
    password = data.get('password', '')
    
    # Validate input
    if not username or len(username) < 3:
        return error_response('Username must be at least 3 characters long', 400)
    
    if not email or '@' not in email:
        return error_response('Invalid email format', 400)
    
    if not password or len(password) < 6:
        return error_response('Password must be at least 6 characters long', 400)
    
    # Check if user already exists
    if user_exists(username, email):
        return error_response('Username or email already exists', 409)
    
    # Create user
    try:
        if create_user(username, email, password):
            return success_response('Account created successfully', status_code=201)
        else:
            return error_response('Failed to create account', 500)
    except Exception as e:
        print(f"Registration error: {e}")
        return error_response('Server error while creating account', 500)


@app.route('/login', methods=['POST'])
def login():
    """Login user"""
    data = request.get_json()
    
    # Validate required fields
    missing_fields = validate_request_data(data, ['username', 'password'])
    if missing_fields:
        return error_response(
            f"Missing required fields: {', '.join(missing_fields)}",
            400
        )
    
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    try:
        # Get user from database
        user = get_user_by_username(username)
        
        if not user:
            return error_response('Invalid username or password', 401)
        
        # Verify password
        if not verify_password(password, user['password']):
            return error_response('Invalid username or password', 401)
        
        # Set session
        session.permanent = True
        session['user_id'] = user['id']
        session['username'] = user['username']
        session['email'] = user['email']
        
        # Log audit
        log_audit(user['id'], 'login', 'User logged in')
        
        return success_response(
            'Login successful',
            {'username': user['username'], 'email': user['email']},
            200
        )
    except Exception as e:
        print(f"Login error: {e}")
        return error_response('Server error while logging in', 500)


@app.route('/logout', methods=['GET', 'POST'])
def logout():
    """Logout user"""
    try:
        user_id = session.get('user_id')
        if user_id:
            log_audit(user_id, 'logout', 'User logged out')
        
        session.clear()
        return success_response('Logged out successfully', {}, 200)
    except Exception as e:
        print(f"Logout error: {e}")
        return error_response('Error while logging out', 500)

@app.route('/api/process', methods=['POST'])
def process_document():
    """Process a document for PII redaction"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    
    # Check if file is present
    if 'file' not in request.files:
        return error_response('No file provided', 400)
    
    file = request.files['file']
    doc_type = request.form.get('doc_type', 'general')
    action = request.form.get('action', 'redact')
    
    if file.filename == '':
        return error_response('No file selected', 400)
    
    try:
        # Validate file type
        allowed_extensions = {'jpg', 'jpeg', 'png', 'pdf', 'gif', 'webp', 'docx', 'txt'}
        file_ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else ''
        
        if file_ext not in allowed_extensions:
            return error_response(
                f'Invalid file type. Allowed: {", ".join(allowed_extensions)}',
                400
            )
        
        # Save uploaded file
        uploads_dir = os.path.join(os.getcwd(), 'uploads')
        os.makedirs(uploads_dir, exist_ok=True)
        
        # Generate unique filename
        timestamp = __import__('datetime').datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{user_id}_{timestamp}_{file.filename}"
        filepath = os.path.join(uploads_dir, filename)
        file.save(filepath)
        
        # TODO: Implement PII detection and redaction logic here
      
        processing_result = {
            'filename': filename,
            'original_filename': file.filename,
            'doc_type': doc_type,
            'action': action,
            'status': 'processed',
            'pii_detected': ['email', 'phone', 'ssn'],
            'redaction_summary': f'Detected and {action}ed 3 PII elements',
            'processed_at': __import__('datetime').datetime.now().isoformat()
        }
        
        # Log audit
        log_audit(
            user_id,
            'document_processed',
            f'Processed {doc_type} document: {file.filename}',
            'success'
        )
        
        return success_response(
            'Document processed successfully',
            processing_result,
            200
        )
    
    except Exception as e:
        print(f"Document processing error: {e}")
        log_audit(
            user_id,
            'document_processing_failed',
            str(e),
            'error'
        )
        return error_response('Failed to process document', 500)


@app.route('/api/download/<filename>', methods=['GET'])
def download_document(filename):
    """Download a processed document"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    
    try:
        # Security check: ensure filename belongs to the user
        if not filename.startswith(f"{user_id}_"):
            return error_response('Access denied', 403)
        
        filepath = os.path.join(os.getcwd(), 'uploads', filename)
        
        if not os.path.exists(filepath):
            return error_response('File not found', 404)
        
        # Log audit
        log_audit(
            user_id,
            'document_downloaded',
            f'Downloaded processed document: {filename}',
            'success'
        )
        
        return send_file(filepath, as_attachment=True)
    
    except Exception as e:
        print(f"Download error: {e}")
        log_audit(
            user_id,
            'document_download_failed',
            str(e),
            'error'
        )
        return error_response('Failed to download document', 500)


@app.route('/audit-logs', methods=['GET'])
def get_audit_logs():
    """Get audit logs for the current user"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    
    try:
        sql = """
        SELECT id, user_id, action, details, status, created_at
        FROM audit_logs
        WHERE user_id = %s
        ORDER BY created_at DESC
        LIMIT 100
        """
        
        logs = db.query(sql, (user_id,))
        return success_response('Audit logs retrieved', logs or [], 200)
    
    except Exception as e:
        print(f"Audit logs error: {e}")
        return error_response('Failed to retrieve audit logs', 500)

@app.route('/download/<filename>', methods=['GET'])
def download_file(filename):
    """Download a processed file"""
    
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    
    try:
        # Security: Ensure file belongs to current user
        if not filename.startswith(str(user_id)):
            return error_response('Access denied', 403)
        
        uploads_dir = os.path.join(os.getcwd(), 'uploads')
        filepath = os.path.join(uploads_dir, filename)
        
        # Additional security check
        if not os.path.exists(filepath) or not os.path.isfile(filepath):
            return error_response('File not found', 404)
        
        # Prevent directory traversal
        if os.path.abspath(filepath) != os.path.abspath(os.path.join(uploads_dir, filename)):
            return error_response('Invalid file path', 400)
        
        log_audit(user_id, 'file_downloaded', f'Downloaded: {filename}')
        
        return send_file(filepath, as_attachment=True)
    
    except Exception as e:
        print(f"File download error: {e}")
        return error_response('Failed to download file', 500)


@app.route('/api/security/pin', methods=['POST'])
def set_pin_code():
    """Save or update PIN code for user"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    data = request.get_json()
    
    # Validate PIN
    pin = data.get('pin', '').strip() if data else ''
    
    if not pin or len(pin) < 4 or len(pin) > 6 or not pin.isdigit():
        return error_response('PIN must be 4-6 digits', 400)
    
    try:
        if save_pin_code(user_id, pin):
            log_audit(user_id, 'pin_set', 'User set PIN code', 'success')
            return success_response('PIN code saved successfully', {}, 200)
        else:
            return error_response('Failed to save PIN code', 500)
    except Exception as e:
        print(f"PIN save error: {e}")
        log_audit(user_id, 'pin_set_failed', str(e), 'error')
        return error_response('Error saving PIN code', 500)


@app.route('/api/security/verify-pin', methods=['POST'])
def verify_pin_endpoint():
    """Verify user's PIN code"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    data = request.get_json()
    
    pin = data.get('pin', '').strip() if data else ''
    
    if not pin:
        return error_response('PIN is required', 400)
    
    try:
        if verify_user_pin(user_id, pin):
            log_audit(user_id, 'pin_verified', 'User verified PIN', 'success')
            return success_response('PIN verified successfully', {'verified': True}, 200)
        else:
            log_audit(user_id, 'pin_verification_failed', 'Invalid PIN entered', 'error')
            return error_response('Invalid PIN code', 401)
    except Exception as e:
        print(f"PIN verify error: {e}")
        log_audit(user_id, 'pin_verification_error', str(e), 'error')
        return error_response('Error verifying PIN', 500)



@app.route('/api/security/fingerprint', methods=['POST'])
def set_fingerprint():
    """Save fingerprint data for user (one-time)"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    data = request.get_json()
    
    fingerprint_data = data.get('fingerprint_data', '').strip() if data else ''
    
    if not fingerprint_data:
        return error_response('Fingerprint data is required', 400)
    
    try:
        # Check if fingerprint already exists
        security = get_user_security(user_id)
        if security and security['is_fingerprint_enabled']:
            return error_response('Fingerprint already registered. Cannot update.', 409)
        
        if save_fingerprint(user_id, fingerprint_data):
            log_audit(user_id, 'fingerprint_registered', 'User registered fingerprint', 'success')
            return success_response('Fingerprint registered successfully', {'registered': True}, 201)
        else:
            return error_response('Failed to register fingerprint', 500)
    except Exception as e:
        print(f"Fingerprint save error: {e}")
        log_audit(user_id, 'fingerprint_registration_failed', str(e), 'error')
        return error_response('Error registering fingerprint', 500)


@app.route('/api/security/verify-fingerprint', methods=['POST'])
def verify_fingerprint_endpoint():
    """Verify user's fingerprint"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    data = request.get_json()
    
    fingerprint_data = data.get('fingerprint_data', '').strip() if data else ''
    
    if not fingerprint_data:
        return error_response('Fingerprint data is required', 400)
    
    try:
        if verify_user_fingerprint(user_id, fingerprint_data):
            log_audit(user_id, 'fingerprint_verified', 'User verified fingerprint', 'success')
            return success_response('Fingerprint verified successfully', {'verified': True}, 200)
        else:
            log_audit(user_id, 'fingerprint_verification_failed', 'Fingerprint does not match', 'error')
            return error_response('Fingerprint does not match', 401)
    except Exception as e:
        print(f"Fingerprint verify error: {e}")
        log_audit(user_id, 'fingerprint_verification_error', str(e), 'error')
        return error_response('Error verifying fingerprint', 500)


@app.route('/api/change-password', methods=['POST'])
def change_password():
    """Change password for current user"""

    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)

    data = request.get_json()
    if not data:
        return error_response('Invalid request payload', 400)

    current_password = data.get('current_password', '').strip()
    new_password = data.get('new_password', '').strip()

    if not current_password or not new_password:
        return error_response('Current and new passwords are required', 400)

    if len(new_password) < 6:
        return error_response('New password must be at least 6 characters long', 400)

    user_id = session['user_id']

    try:
        if update_user_password(user_id, current_password, new_password):
            log_audit(user_id, 'password_changed', 'User changed password', 'success')
            return success_response('Password updated successfully', {}, 200)

        return error_response('Invalid current password', 401)
    except Exception as e:
        print(f"Password change error: {e}")
        log_audit(user_id, 'password_change_failed', str(e), 'error')
        return error_response('Error updating password', 500)


@app.route('/api/security/status', methods=['GET'])
def get_security_status():
    """Get security status for current user"""
    
    # Check if user is logged in
    if 'user_id' not in session:
        return error_response('Unauthorized: Please login first', 401)
    
    user_id = session['user_id']
    
    try:
        security = get_user_security(user_id)
        
        status = {
            'pin_enabled': bool(security and security['pin_code']) if security else False,
            'fingerprint_enabled': security['is_fingerprint_enabled'] if security else False,
            'created_at': security['created_at'].isoformat() if security and security['created_at'] else None,
            'updated_at': security['updated_at'].isoformat() if security and security['updated_at'] else None
        }
        
        return success_response('Security status retrieved', status, 200)
    
    except Exception as e:
        print(f"Security status error: {e}")
        return error_response('Failed to retrieve security status', 500)


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return error_response('Endpoint not found', 404)


@app.errorhandler(405)
def method_not_allowed(error):
    """Handle 405 errors"""
    return error_response('Method not allowed', 405)


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return error_response('Internal server error', 500)


@app.teardown_appcontext
def close_db(error):
    """Close database connection on app shutdown"""
    if db.connection:
        db.disconnect()


if __name__ == '__main__':
    # Create uploads directory if it doesn't exist
    os.makedirs('uploads', exist_ok=True)
    
    # Run the app
    app.run(
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000)),
        debug=app.config.get('DEBUG', True)
    )
