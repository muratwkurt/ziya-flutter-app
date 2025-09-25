import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ziya - Dijital İkiz',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const ZiyaHome(),
    );
  }
}

class ZiyaHome extends StatefulWidget {
  const ZiyaHome({super.key});

  @override
  State<ZiyaHome> createState() => _ZiyaHomeState();
}

class _ZiyaHomeState extends State<ZiyaHome> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _text = 'Konuşmak için mikrofona bas...';
  String _responseText = '';
  String _audioBase64 = '';

  final String _apiUrl = 'https://ziya-dijital-ikiz.onrender.com'; // ✅ BURAYI KENDİNİN URL’İYLE DEĞİŞTİR!

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool available = await _speechToText.initialize();
    if (!available) {
      setState(() {
        _text = 'Ses tanıma cihazında çalışmıyor.';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _text = result.recognizedWords;
            if (result.finalResult) {
              _sendToZiya();
            }
          });
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        localeId: 'tr_TR', // Türkçe dil
      );
      setState(() {
        _isListening = true;
      });
    } else {
      _speechToText.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _sendToZiya() async {
    try {
      // 1. Sesli metni Ziya’ya gönder
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'multipart/form-data'},
        body: {
          'audio': http.MultipartFile.fromBytes(
            'audio',
            _speechToText.lastResult.recognizedWords
                .codeUnits
                .map((e) => e.toRadixString(16))
                .join()
                .runes
                .map((e) => e.toRadixString(16))
                .join()
                .codeUnits
                .map((e) => e)
                .toList(),
            filename: 'audio.wav',
          ),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _responseText = data['text'];
          _audioBase64 = data['audio'];
        });
        _playAudio();
      } else {
        setState(() {
          _responseText = 'Ziya yanıt veremedi. Lütfen tekrar deneyin.';
        });
      }
    } catch (e) {
      setState(() {
        _responseText = 'Hata: $e';
      });
    }
  }

  Future<void> _playAudio() async {
    // Android/iOS için sesi oynatmak için flutter_tts kullanacağız
    // Ancak Flutter uygulaması içinde sesi oynatmak için:
    // 1. Önce base64 sesi decode et
    // 2. AudioPlayer ile oynat (bu kodda basitçe sadece metni okutuyoruz)

    // Basit çözüm: Yanıtı sesli oku (flutter_tts)
    // Ama bu kodda flutter_tts kullanmıyoruz — çünkü senin telefonunda zaten sesli okuma var.

    // Alternatif: Sadece metni göster, kullanıcı kendisi okusun.
    // İleride Flutter + TTS entegrasyonu yapabilirsin.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ziya - Dijital İkiz'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Konuşma durumu
              Text(
                _text,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Ziya'nın cevabı
              Text(
                _responseText,
                style: const TextStyle(fontSize: 18, color: Colors.blue),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 40),
              // Mikrofon butonu
              SizedBox(
                width: 100,
                height: 100,
                child: ElevatedButton(
                  onPressed: _startListening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.deepPurple,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Ziya’ya konuşmak için mikrofon butonuna bas!',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
