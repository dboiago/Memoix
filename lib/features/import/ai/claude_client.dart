// Claude (Anthropic, Messages API)
final payload = {
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 4096,
  "system": systemPrompt,
  "messages": [
    {
      "role": "user",
      "content": [
        if (imageBase64 != null)
          {
            "type": "image",
            "source": {
              "type": "base64",
              "media_type": "image/jpeg",
              "data": imageBase64
            }
          },
        {
          "type": "text",
          "text": extractedText ?? ""
        }
      ]
    }
  ]
};
