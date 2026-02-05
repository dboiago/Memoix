// Gemini (Google AI Studio / Vertex)
final payload = {
  "contents": [
    {
      "role": "user",
      "parts": [
        if (imageBase64 != null)
          {
            "inlineData": {
              "mimeType": "image/jpeg",
              "data": imageBase64
            }
          },
        {
          "text": systemPrompt + "\n\n" + (extractedText ?? "")
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.1,
    "responseMimeType": "application/json"
  }
};
