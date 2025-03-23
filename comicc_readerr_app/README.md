# Comic Reader App

A Flutter application for reading comic books (CBZ files) with support for local and server-based comics.

## Features

- Read CBZ comics from local storage
- Connect to a server to browse and read comics without downloading them
- Convert CBR to CBZ format 
- Smooth page turning animations
- Library management with reading progress tracking
- Full-screen reading mode
- Zoom and pan controls

## Server Integration

The app can connect to a Flask-based API server to browse and read comics without downloading the entire file. The server should implement the following endpoints:

- `/list-cbz` - Lists all CBZ files on the server
- `/preview-cbz` - Returns the first page of a CBZ file as a base64-encoded image
- `/page-cbz` - Returns a specific page from a CBZ file as a base64-encoded image
- `/convert-cbr` - Converts a CBR file to CBZ format
- `/download-cbz` - Downloads a full CBZ file (optional - for full downloads)

## Using Server Comics

1. Enter your server URL in the Downloads page (format: `http://your-ip:port`)
2. Browse available comics on the server
3. Add comics to your library by clicking the "Add" button
4. Open the comic from your library - pages will be loaded on-demand as you read

The app intelligently loads comic pages on-demand when reading server-based comics, which:
- Reduces bandwidth usage by only loading pages as needed
- Provides faster initial load times
- Allows access to a large comic collection without device storage limitations

## Setup

1. Ensure you have Flutter installed
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run the app using `flutter run`

## Server Setup

For server functionality, you'll need to set up the Flask API server. See the example implementation in `server_side_example.py`.

```python
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import base64
import zipfile
import rarfile
import io
import shutil

app = Flask(__name__)
CORS(app)

CBZ_DIRECTORY = "comics"
if not os.path.exists(CBZ_DIRECTORY):
    os.makedirs(CBZ_DIRECTORY)

@app.route('/list-cbz', methods=['GET'])
def list_cbz():
    try:
        files = [f for f in os.listdir(CBZ_DIRECTORY) if f.lower().endswith('.cbz')]
        return jsonify({"files": files})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/preview-cbz', methods=['POST'])
def preview_cbz():
    try:
        data = request.json
        filename = data.get('filename')
        
        if not filename:
            return jsonify({"error": "Filename is required"}), 400
            
        filepath = os.path.join(CBZ_DIRECTORY, filename)
        
        with zipfile.ZipFile(filepath, 'r') as zip_ref:
            image_files = [f for f in zip_ref.namelist() if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            image_files.sort()
            
            if not image_files:
                return jsonify({"error": "No images found in CBZ file"}), 404
                
            with zip_ref.open(image_files[0]) as first_image:
                image_data = first_image.read()
                base64_data = base64.b64encode(image_data).decode('utf-8')
                return jsonify({"image": base64_data})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/page-cbz', methods=['POST'])
def page_cbz():
    try:
        data = request.json
        filename = data.get('filename')
        page = data.get('page', 0)
        
        if not filename:
            return jsonify({"error": "Filename is required"}), 400
            
        filepath = os.path.join(CBZ_DIRECTORY, filename)
        
        with zipfile.ZipFile(filepath, 'r') as zip_ref:
            image_files = [f for f in zip_ref.namelist() if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            image_files.sort()
            
            if page >= len(image_files):
                return jsonify({"error": f"Page {page} not found. Comic has {len(image_files)} pages"}), 404
                
            with zip_ref.open(image_files[page]) as image_file:
                image_data = image_file.read()
                base64_data = base64.b64encode(image_data).decode('utf-8')
                return jsonify({"image": base64_data})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/convert-cbr', methods=['POST'])
def convert_cbr():
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file part"}), 400
            
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400
            
        if not file.filename.lower().endswith('.cbr'):
            return jsonify({"error": "File must be a CBR file"}), 400
            
        temp_dir = os.path.join(os.getcwd(), "temp")
        if not os.path.exists(temp_dir):
            os.makedirs(temp_dir)
            
        cbr_path = os.path.join(temp_dir, file.filename)
        file.save(cbr_path)
        
        # Extract CBR
        extract_dir = os.path.join(temp_dir, "extracted")
        if os.path.exists(extract_dir):
            shutil.rmtree(extract_dir)
        os.makedirs(extract_dir)
        
        with rarfile.RarFile(cbr_path, 'r') as rar_ref:
            rar_ref.extractall(extract_dir)
        
        # Create CBZ
        cbz_filename = os.path.splitext(file.filename)[0] + ".cbz"
        cbz_path = os.path.join(CBZ_DIRECTORY, cbz_filename)
        
        with zipfile.ZipFile(cbz_path, 'w') as zip_ref:
            for root, dirs, files in os.walk(extract_dir):
                for file in files:
                    if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                        zip_ref.write(
                            os.path.join(root, file),
                            arcname=os.path.relpath(os.path.join(root, file), extract_dir)
                        )
        
        # Clean up
        shutil.rmtree(extract_dir)
        os.remove(cbr_path)
        
        return jsonify({"message": "Conversion successful", "output": cbz_filename})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/download-cbz', methods=['POST'])
def download_cbz():
    try:
        data = request.json
        filename = data.get('filename')
        
        if not filename:
            return jsonify({"error": "Filename is required"}), 400
            
        filepath = os.path.join(CBZ_DIRECTORY, filename)
        
        if not os.path.exists(filepath):
            return jsonify({"error": "File not found"}), 404
            
        return send_file(
            filepath,
            mimetype='application/zip',
            as_attachment=True,
            download_name=filename
        )
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
```

Make sure to install the required Python packages: `flask`, `flask-cors`, `rarfile`

Run the server with: `python server_side_example.py`
