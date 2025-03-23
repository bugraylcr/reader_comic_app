import os
import zipfile
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import rarfile
import shutil
from pathlib import Path
from PIL import Image
from io import BytesIO
import threading
import platform

BASE_DIR = Path(__file__).resolve().parent
COMIC_CONVERTER_FOLDER = BASE_DIR / "ComicConverter"
CACHE_FOLDER = COMIC_CONVERTER_FOLDER / "cached"

if not COMIC_CONVERTER_FOLDER.exists():
    COMIC_CONVERTER_FOLDER.mkdir(parents=True, exist_ok=True)
if not CACHE_FOLDER.exists():
    CACHE_FOLDER.mkdir(parents=True, exist_ok=True)

# Platform kontrolü ile unrar yolu
if platform.system() == "Windows":
    rarfile.UNRAR_TOOL = "C:\\Program Files\\WinRAR\\UnRAR.exe"
else:
    rarfile.UNRAR_TOOL = "/usr/bin/unrar"

app = Flask(__name__)
CORS(app)

def delayed_remove(directory, delay=600):
    timer = threading.Timer(delay, lambda: shutil.rmtree(directory, ignore_errors=True))
    timer.start()

def resize_image(image_path, max_width=1400, max_height=2150):
    with Image.open(image_path) as img:
        if img.mode != "RGB":
            img = img.convert("RGB")

        img_ratio = img.width / img.height
        target_ratio = max_width / max_height

        if img_ratio > target_ratio:
            target_width = max_width
            target_height = int(max_width / img_ratio)
        else:
            target_height = max_height
            target_width = int(max_height * img_ratio)

        img = img.resize((target_width, target_height), Image.LANCZOS)

        buffer = BytesIO()
        img.save(buffer, format="WEBP", quality=90, method=6)
        return buffer.getvalue()

def extract_images(cbz_path):
    extract_folder = COMIC_CONVERTER_FOLDER / (Path(cbz_path).stem + "_extracted")
    with zipfile.ZipFile(cbz_path, 'r') as zip_ref:
        zip_ref.extractall(str(extract_folder))

    images = []
    for root, dirs, files in os.walk(extract_folder, followlinks=False):
        for file in files:
            fullpath = os.path.join(root, file)
            if os.path.islink(fullpath):
                continue
            if file.lower().endswith(('.jpg', '.png')):
                images.append(fullpath)
    images.sort()
    return images, extract_folder

@app.route('/list-cbz', methods=['GET'])
def list_cbz():
    cbz_files = [f for f in os.listdir(COMIC_CONVERTER_FOLDER) if f.lower().endswith(".cbz")]
    return jsonify({"files": cbz_files})

@app.route('/preview-cbz', methods=['POST'])
def preview_cbz():
    data = request.get_json()
    if not data or "filename" not in data:
        return jsonify({"error": "filename alanı gereklidir."}), 400

    filename = data["filename"]
    cbz_path = COMIC_CONVERTER_FOLDER / filename
    if not cbz_path.exists():
        return jsonify({"error": "Dosya bulunamadı."}), 404

    images, extract_folder = extract_images(str(cbz_path))
    if not images:
        delayed_remove(extract_folder, delay=600)
        return jsonify({"error": "Dosyada resim bulunamadı."}), 404

    first_image = images[0]
    cache_path = CACHE_FOLDER / Path(filename).stem / "preview.webp"
    cache_path.parent.mkdir(parents=True, exist_ok=True)

    if cache_path.exists():
        return send_file(str(cache_path), mimetype='image/webp')
    else:
        image_bytes = resize_image(first_image)
        with open(cache_path, "wb") as f:
            f.write(image_bytes)
        return send_file(BytesIO(image_bytes), mimetype='image/webp')

@app.route('/page-cbz', methods=['POST'])
def page_cbz():
    data = request.get_json()
    if not data or "filename" not in data or "page" not in data:
        return jsonify({"error": "filename ve page alanları gereklidir."}), 400

    filename = data["filename"]
    page_num = data["page"]

    cbz_path = COMIC_CONVERTER_FOLDER / filename
    if not cbz_path.exists():
        return jsonify({"error": "Dosya bulunamadı."}), 404

    images, extract_folder = extract_images(str(cbz_path))
    if not images:
        delayed_remove(extract_folder, delay=600)
        return jsonify({"error": "Dosyada resim bulunamadı."}), 404

    if not isinstance(page_num, int) or page_num < 1 or page_num > len(images):
        delayed_remove(extract_folder, delay=600)
        return jsonify({"error": f"Geçersiz sayfa numarası. Toplam sayfa: {len(images)}"}), 400

    selected_image = images[page_num - 1]
    cache_path = CACHE_FOLDER / Path(filename).stem / f"page_{page_num}.webp"
    cache_path.parent.mkdir(parents=True, exist_ok=True)

    if cache_path.exists():
        return send_file(str(cache_path), mimetype='image/webp')
    else:
        image_bytes = resize_image(selected_image)
        with open(cache_path, "wb") as f:
            f.write(image_bytes)
        return send_file(BytesIO(image_bytes), mimetype='image/webp')

def convert_cbr_to_cbz(input_cbr):
    base_name = Path(input_cbr).stem
    output_cbz = COMIC_CONVERTER_FOLDER / f"{base_name}.cbz"
    temp_folder = COMIC_CONVERTER_FOLDER / f"{base_name}_temp"
    temp_folder.mkdir(parents=True, exist_ok=True)

    try:
        with rarfile.RarFile(input_cbr) as rf:
            rf.extractall(str(temp_folder))
        with zipfile.ZipFile(str(output_cbz), 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, _, files in os.walk(temp_folder):
                for file in files:
                    file_path = os.path.join(root, file)
                    zf.write(file_path, os.path.relpath(file_path, str(temp_folder)))
        return str(output_cbz), None
    except Exception as e:
        return None, str(e)
    finally:
        shutil.rmtree(temp_folder, ignore_errors=True)

@app.route('/convert-cbr', methods=['POST'])
def convert_cbr():
    if 'file' not in request.files:
        return jsonify({"error": "Dosya yüklenmedi."}), 400

    file = request.files['file']
    if not file.filename.lower().endswith('.cbr'):
        return jsonify({"error": "Yüklenen dosya CBR formatında değil."}), 400

    input_path = COMIC_CONVERTER_FOLDER / file.filename
    file.save(str(input_path))

    output_cbz, error = convert_cbr_to_cbz(str(input_path))
    os.remove(str(input_path))

    if error:
        return jsonify({"error": error}), 500

    return jsonify({"message": "Dönüştürme başarılı.", "output": Path(output_cbz).name})

@app.route('/upload-cbz', methods=['POST'])
def upload_cbz():
    if 'file' not in request.files:
        return jsonify({"error": "Dosya yüklenmedi."}), 400

    file = request.files['file']
    if not file.filename.lower().endswith('.cbz'):
        return jsonify({"error": "Yüklenen dosya CBZ formatında değil."}), 400

    filename = file.filename
    output_path = COMIC_CONVERTER_FOLDER / filename
    file.save(str(output_path))

    return jsonify({"message": "CBZ başarıyla yüklendi.", "filename": filename}), 200

@app.route('/delete-cbz', methods=['POST'])
def delete_cbz():
    data = request.get_json()
    if not data or "filename" not in data:
        return jsonify({"error": "filename alanı gereklidir."}), 400

    filename = data["filename"]
    cbz_path = COMIC_CONVERTER_FOLDER / filename
    cache_path = CACHE_FOLDER / Path(filename).stem

    errors = []

    if cbz_path.exists():
        try:
            cbz_path.unlink()
        except Exception as e:
            errors.append(f"CBZ silinemedi: {str(e)}")

    if cache_path.exists():
        try:
            shutil.rmtree(cache_path, ignore_errors=True)
        except Exception as e:
            errors.append(f"Cache silinemedi: {str(e)}")

    if errors:
        return jsonify({"message": "Kısmen silindi.", "errors": errors}), 207

    return jsonify({"message": "Başarıyla silindi."}), 200

if __name__ == '__main__':
    from waitress import serve
    serve(app, host='0.0.0.0', port=5000, threads=20)
