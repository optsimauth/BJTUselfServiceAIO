import torch
import numpy as np, torch, onnxruntime as ort

PT_PATH = r"D:\Flutter\bjtuselfserviceaio\BJTUselfService\app\src\main\assets\model.pt"
ONNX_PATH = "model.onnx"

model = torch.jit.load(PT_PATH, map_location="cpu")
model.eval()


# ★ 关键：强制把整个图里所有模块都切到 eval
def force_eval(m):
    m.eval()
    for child in m.children():
        force_eval(child)


force_eval(model)

# 再确认一下
assert not model.training, "model still in training mode!"

dummy = torch.randn(1, 3, 42, 130)

torch.onnx.export(
    model,
    dummy,
    ONNX_PATH,
    input_names=["input"],
    output_names=["output"],
    opset_version=12,
    training=torch.onnx.TrainingMode.EVAL,  # ★ 明确指定 EVAL
    dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
)

print("saved:", ONNX_PATH)
print("jiazai")
model = torch.jit.load(PT_PATH, map_location="cpu")
force_eval(model)
print("jiazai")
dummy = torch.randn(1, 3, 42, 130)
with torch.no_grad():
    pt_out = model(dummy).numpy()

sess = ort.InferenceSession("model.onnx")
onnx_out = sess.run(None, {"input": dummy.numpy()})[0]

print("pt   shape:", pt_out.shape)
print("onnx shape:", onnx_out.shape)
print("max diff  :", np.abs(pt_out - onnx_out).max())
