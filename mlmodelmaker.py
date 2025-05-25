import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
import coremltools as ct

# --- Generate training data ---
np.random.seed(42)
normal_data = np.random.normal(loc=100, scale=15, size=(1000,))
anomalies = np.random.normal(loc=300, scale=5, size=(20,))
all_data = np.concatenate([normal_data, anomalies])
df = pd.DataFrame({'request_rate': all_data})

# --- Train Isolation Forest model ---
model = IsolationForest(contamination=0.02)
model.fit(df[['request_rate']])

# --- Wrap model in a function for CoreML ---
def predict_fn(data):
    scores = model.decision_function(data)
    return (scores < 0).astype(int)  # 1 = anomaly

# --- Convert to CoreML model ---
input_features = ct.TensorType(name="request_rate", shape=(1,))
output_features = ct.TensorType(name="isAnomalous", shape=(1,), dtype=ct.converters.mil.input_types.Int64)

coreml_model = ct.convert(
    model,
    inputs=[input_features],
    outputs=[output_features],
    classifier_config=None
)

coreml_model.save("AnomalyDetector.mlmodel")
print("✅ Saved: AnomalyDetector.mlmodel")
