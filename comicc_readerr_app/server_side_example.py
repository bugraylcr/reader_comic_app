from flask import Flask, request, jsonify, send_file
import os
import json
from flask_cors import CORS  # Import for handling CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Set the CBZ directory (this should be configured according to your actual setup)
CBZ_DIRECTORY = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'cbz_files')

# Ensure the directory exists
os.makedirs(CBZ_DIRECTORY, exist_ok=True)

@app.route('/list-cbz', methods=['GET'])
def list_cbz_files():
    """List all .cbz files in the directory"""
    try:
        # Get all files with .cbz extension
        files = [f for f in os.listdir(CBZ_DIRECTORY) if f.endswith('.cbz')]
        return jsonify({"files": files})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/preview-cbz', methods=['POST'])
def preview_cbz():
    """Get a preview (first page) of a CBZ file"""
    try:
        data = request.json
        filename = data.get('filename')
        thumbnail = data.get('thumbnail', False)
        max_size = data.get('max_size', 1024)
        
        # Implement your logic to extract the first image from the CBZ
        # and return it as base64
        # For this example, we're just returning a placeholder
        
        # Mock image data (in real implementation, extract from CBZ)
        import base64
        with open('placeholder.jpg', 'rb') as img_file:
            base64_image = base64.b64encode(img_file.read()).decode('utf-8')
        
        return jsonify({"image": base64_image})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/page-cbz', methods=['POST'])
def get_page_cbz():
    """Get a specific page from a CBZ file"""
    try:
        data = request.json
        filename = data.get('filename')
        page = data.get('page', 0)
        max_size = data.get('max_size', 1200)
        
        # Implement your logic to extract the specific page from the CBZ
        # and return it as base64
        # Similar to preview_cbz but extracting a specific page
        
        # Mock image data (in real implementation, extract from CBZ)
        import base64
        with open('placeholder.jpg', 'rb') as img_file:
            base64_image = base64.b64encode(img_file.read()).decode('utf-8')
        
        return jsonify({"image": base64_image})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/convert-cbr', methods=['POST'])
def convert_cbr_to_cbz():
    """Convert a CBR file to CBZ"""
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file part"}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400
        
        # Implement your CBR to CBZ conversion logic here
        # For this example, we're just acknowledging receipt
        
        return jsonify({"output": "Conversion successful"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/download-cbz', methods=['POST'])
def download_cbz():
    """Download a specific CBZ file"""
    try:
        data = request.json
        filename = data.get('filename')
        
        if not filename:
            return jsonify({"error": "Filename is required"}), 400
        
        file_path = os.path.join(CBZ_DIRECTORY, filename)
        
        # Check if file exists
        if not os.path.exists(file_path):
            return jsonify({"error": f"File {filename} not found"}), 404
        
        # Return the file as an attachment
        return send_file(
            file_path, 
            as_attachment=True,
            download_name=filename,
            mimetype='application/zip'
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 