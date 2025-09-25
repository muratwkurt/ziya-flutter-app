from flask import Flask, request, jsonify
import requests
import base64
import os

app = Flask(__name__)

# API anahtarları (Railway otomatik verir)
OPENROUTER_KEY = os.getenv("OPENROUTER_KEY")
ELEVENLABS_KEY = os.getenv("ELEVENLABS_KEY")
ASSEMBLYAI_KEY = os.getenv("ASSEMBLYAI_KEY")

@app.route("/", methods=["POST"])
def ziya_hello():
    # 1. Ses dosyasını al (WAV formatında)
    if "audio" not in request.files:
        return jsonify({"error": "Ses dosyası bulunamadı!"}), 400

    audio_file = request.files["audio"]
    audio_bytes = audio_file.read()

    # 2. AssemblyAI ile sesi metne çevir
    upload_url = "https://api.assemblyai.com/v2/upload"
    headers = {"authorization": ASSEMBLYAI_KEY}
    upload_response = requests.post(upload_url, headers=headers, data=audio_bytes)
    audio_url = upload_response.json()["upload_url"]

    # Transkripsiyon isteği
    transcribe_url = "https://api.assemblyai.com/v2/transcript"
    transcribe_data = {"audio_url": audio_url}
    transcribe_response = requests.post(transcribe_url, json=transcribe_data, headers=headers)
    transcript_id = transcribe_response.json()["id"]

    # Sonucu bekle
    while True:
        result_url = f"https://api.assemblyai.com/v2/transcript/{transcript_id}"
        result_response = requests.get(result_url, headers=headers)
        result = result_response.json()
        if result["status"] == "completed":
            user_text = result["text"]
            break
        elif result["status"] == "error":
            return jsonify({"error": "Ses tanıma hatası!"}), 500

    # 3. OpenRouter ile Qwen3'ten yanıt al
    openrouter_url = "https://openrouter.ai/api/v1/chat/completions"
    openrouter_headers = {
        "Authorization": f"Bearer {OPENROUTER_KEY}",
        "HTTP-Referer": "https://ziya-dijital-ikiz.onrender.com",
        "X-Title": "Ziya-Dijital-Ikiz"
    }
    openrouter_data = {
        "model": "qwen/qwen3-235b-a22b-2507",
        "messages": [
            {
                "role": "system",
                "content": "Sen Ziya'sın. Bir dijital ikizsin. Kullanıcıya arkadaşça, empatik, bilimsel ve psikolojik bir yanıt ver. Türkçe ve İngilizce konuşabilirsin. Yanıtlar kısa, doğal ve insan gibi olmalı."
            },
            {
                "role": "user",
                "content": user_text
            }
        ]
    }
    ai_response = requests.post(openrouter_url, json=openrouter_data, headers=openrouter_headers)
    ai_text = ai_response.json()["choices"][0]["message"]["content"]

    # 4. ElevenLabs ile seslendir
    tts_url = f"https://api.elevenlabs.io/v1/text-to-speech/mBUB5zYuPwfVE6DTcEjf"
    tts_headers = {
        "xi-api-key": ELEVENLABS_KEY,
        "Content-Type": "application/json"
    }
    tts_data = {
        "text": ai_text,
        "model_id": "eleven_multilingual_v2"
    }
    tts_response = requests.post(tts_url, json=tts_data, headers=tts_headers)

    # 5. Ses dosyasını base64 olarak döndür
    audio_base64 = base64.b64encode(tts_response.content).decode('utf-8')

    return jsonify({
        "text": ai_text,
        "audio": audio_base64
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)))
