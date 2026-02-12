# Sentiment Analysis Model Setup

This directory contains the TensorFlow Lite model and vocabulary files for on-device sentiment analysis.

## 📥 Required Files

You need to place the following files in this directory:

1. **`sentiment_model.tflite`** - The quantized TFLite model (~20-25 MB)
2. **`vocab.txt`** - Vocabulary file for tokenization (~500 KB)

## 🚀 Quick Setup Instructions

### Method 1: Use Pre-trained Multilingual Model (Recommended)

1. **Download the model from Hugging Face:**

   Visit one of these options:
   
   **Option A: Multilingual MiniLM (Best balance)**
   ```bash
   # Download from: https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
   ```

   **Option B: Pre-converted TFLite models**
   ```bash
   # Search Hugging Face for "multilingual sentiment tflite"
   # Example: https://huggingface.co/models?search=multilingual+sentiment+tflite
   ```

2. **Convert to TFLite (if needed):**

   If you download a PyTorch/TensorFlow SavedModel, convert it using Python:

   ```python
   # Install dependencies
   pip install transformers tensorflow

   # Convert script (save as convert_model.py)
   import tensorflow as tf
   from transformers import TFAutoModelForSequenceClassification, AutoTokenizer

   model_name = "nlptown/bert-base-multilingual-uncased-sentiment"
   
   # Load model
   model = TFAutoModelForSequenceClassification.from_pretrained(model_name)
   tokenizer = AutoTokenizer.from_pretrained(model_name)
   
   # Save vocabulary
   vocab = tokenizer.get_vocab()
   with open('vocab.txt', 'w', encoding='utf-8') as f:
       for word, idx in sorted(vocab.items(), key=lambda x: x[1]):
           f.write(f"{word}\n")
   
   # Convert to TFLite with quantization
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   converter.optimizations = [tf.lite.Optimize.DEFAULT]
   tflite_model = converter.convert()
   
   # Save model
   with open('sentiment_model.tflite', 'wb') as f:
       f.write(tflite_model)
   
   print("✅ Model converted successfully!")
   print(f"Model size: {len(tflite_model) / 1024 / 1024:.2f} MB")
   ```

   Run: `python convert_model.py`

3. **Copy files to this directory:**
   ```
   assets/models/
   ├── sentiment_model.tflite
   └── vocab.txt
   ```

### Method 2: Use a Lightweight Model (<10 MB)

For a smaller app size, use a compact sentiment model:

```python
# Use distilled model
model_name = "distilbert-base-multilingual-cased"

# Or use a custom lightweight model
# This will result in ~8-12 MB total size
```

## 🧪 Testing Your Model

After adding the files, test the integration:

1. Run the app
2. Import a WhatsApp chat
3. Check the sentiment analysis results in the UI

## 📊 Expected Model Specifications

### Input
- **Type:** INT32 tensor
- **Shape:** `[1, 128]` (batch_size=1, sequence_length=128)
- **Description:** Tokenized and padded text

### Output
- **Type:** FLOAT32 tensor
- **Shape:** `[1, 3]` (batch_size=1, num_classes=3)
- **Description:** Sentiment scores [positive, negative, neutral]

## 🔧 Troubleshooting

### Model Not Loading

**Error:** "Failed to initialize sentiment analyzer"

- **Check:** Files exist in `assets/models/`
- **Check:** Files are named correctly (case-sensitive)
- **Check:** Model format is TFLite (`.tflite` extension)

### Vocabulary Issues

**Warning:** "Vocabulary file not found, using basic tokenization"

- The app will still work but with reduced accuracy
- Add `vocab.txt` for better results

### App Size Too Large

If your app size increases too much:

1. Use INT8 quantization (reduces size by 4x)
2. Reduce vocabulary size (keep top 10,000 words)
3. Use a distilled model variant

## 📝 Alternative: Skip Model Download (Testing)

For testing without a model, the app will still work but sentiment analysis will be disabled. You'll see this message in the console:

```
⚠️ Sentiment analyzer not initialized
```

## 🌍 Supported Languages

With Multilingual MiniLM, you get support for:

- English, Spanish, French, German, Italian, Portuguese
- Dutch, Polish, Russian, Arabic, Hindi, Chinese
- Japanese, Korean, Turkish, and 40+ more languages

## 📚 Additional Resources

- [TensorFlow Lite Models](https://www.tensorflow.org/lite/models)
- [Hugging Face Models](https://huggingface.co/models?pipeline_tag=text-classification&sort=downloads)
- [Sentiment Analysis Guide](https://www.tensorflow.org/lite/examples/text_classification/overview)

## 🎯 Recommended Models by Size

| Model | Size | Accuracy | Languages | Link |
|-------|------|----------|-----------|------|
| Multilingual MiniLM | ~25 MB | Excellent | 50+ | [Link](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2) |
| DistilBERT Multi | ~32 MB | Best | 100+ | [Link](https://huggingface.co/distilbert-base-multilingual-cased) |
| Lightweight LSTM | ~5 MB | Good | English | Custom training needed |
| TinyBERT | ~15 MB | Very Good | English | [Link](https://huggingface.co/huawei-noah/TinyBERT_General_4L_312D) |

---

**Note:** This app performs all sentiment analysis **on-device**. No data is ever sent to any server, ensuring complete privacy for your WhatsApp chats.
