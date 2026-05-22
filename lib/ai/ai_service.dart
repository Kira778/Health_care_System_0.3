import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AIService {


  // ⚠️ تم التصحيح: المفتاح هو الـ API key، والـ model هو اسم الموديل
   // مفتاح HuggingFace
   // اسم الموديل



//
//
//
// 
//   // Chat مع LLM


  Future<String> getChatResponse(String message) async {
    try {
      final url = Uri.parse("https://router.huggingface.co/v1/chat/completions");
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {"role": "user", "content": message},
          ],
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'];
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content'] ?? "لا يوجد رد";
        }
        return "لا يوجد رد";
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return "حدث خطأ في الاتصال بالذكاء الاصطناعي";
      }
    } catch (e) {
      print('AI Service Error: $e');
      return "حدث خطأ: ${e.toString()}";
    }
  }

  // تحليل BPM
  Future<Map<String, dynamic>> analyzeBPM(int bpm) async {
    await Future.delayed(const Duration(seconds: 1));

    if (bpm < 60) {
      return {
        'status': 'منخفض',
        'recommendations': ['استرح قليلًا', 'اشرب ماء', 'تجنب الإجهاد'],
        'color': Colors.orange,
      };
    } else if (bpm <= 100) {
      return {
        'status': 'طبيعي',
        'recommendations': ['حافظ على نشاطك الطبيعي', 'نم جيدًا', 'مارس الرياضة بانتظام'],
        'color': Colors.green,
      };
    } else {
      return {
        'status': 'مرتفع',
        'recommendations': ['استرخِ وخذ نفسًا عميقًا', 'تجنب المجهود الشديد', 'استشر طبيبك'],
        'color': Colors.red,
      };
    }
  }
}