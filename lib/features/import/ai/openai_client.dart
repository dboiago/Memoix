final payload = {
  "model": "gpt-4.1",
  "response_format": {
    "type": "json_object"
  },
  "messages": [
    {
      "role": "system",
      "content": systemPrompt
    },
    {
      "role": "user",
      "content": [
        if (imageBase64 != null)
          {
            "type": "input_image",
            "image_base64": imageBase64
          },
        {
          "type": "input_text",
          "text": extractedText ?? ""
        }
      ]
    }
  ]
};
