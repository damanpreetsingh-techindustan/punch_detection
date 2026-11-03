# Models

## face_recognition_sface_int8.tflite

Face embedding model used by the subject lock's face check
(`lib/features/vision_detection/data/face/sface_embedder.dart`).

- **Model:** SFace (MobileFaceNet-type network trained with the SFace loss),
  from the OpenCV Model Zoo: `face_recognition_sface_2021dec.onnx`
  (https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface,
  mirrored at https://huggingface.co/opencv/face_recognition_sface).
- **License:** Apache License 2.0 (all files in that model directory).
- **Published accuracy:** 99.60 % on LFW at cosine similarity 0.363 (OpenCV
  DNN face tutorial). The lock's user / other levels sit around that point.
- **Input:** 1 × 112 × 112 × 3, RGB, float 0–255, face aligned to the
  standard 5-point template (eyes, nose tip, mouth corners). **Output:** 1 × 128.
- **Conversion:** ONNX → TFLite with onnx2tf 1.28.8 (float32), then
  TensorFlow 2.19 `TFLiteConverter` with `Optimize.DEFAULT` (weight-only int8,
  9.9 MB). Checked on 57 real aligned face crops: cosine agreement with the
  ONNX model ≥ 0.996 per face, same separation between two people.
- sha256 (tflite): `a884e0f2d514814c02ced1ba439f2b49976c37c70cc03044f31597e0eae6e79c`
- sha256 (source onnx): `27efda6a8074ab5eaa3416ba9dfaf68e45ed10049a09552cb6049a07fabcd299`
