"""把 TorchScript 验证码模型导出为 ONNX，并用 onnxruntime 复跑验证。

model.pt 是训练态保存的：TorchScript 图把 BN 的 train 标志固化成 True，
torch 侧的 .eval() 改不动它。实测只有这个状态认得出验证码（BN 用当前样本的
统计量，等于做了 InstanceNorm，滑动统计量则是坏的）。所以 onnx 必须保留 BN 的
训练态算法，只把随机的 dropout 换成恒等映射：结果才稳定、且和原流程一致。

用法:
    python windows/assets/convert_to_onnx.py [验证码图片 ...]
"""
import sys
from pathlib import Path

import numpy as np
import onnx
import onnxruntime
import torch
import torch.nn.functional as F

ASSETS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(ASSETS_DIR))

from captcha_recognizer import decode_output, load_image  # noqa: E402

MODEL_PT = ASSETS_DIR / 'model.pt'
MODEL_ONNX = ASSETS_DIR / 'model.onnx'
INPUT_SHAPE = (1, 3, 42, 130)
BN_EPS, BN_MOMENTUM = 1e-5, 0.9
TOLERANCE = 1e-4


def load_model(model_pt: Path):
    return torch.jit.load(str(model_pt), map_location='cpu').eval()


def export_module(module, model_onnx: Path, opset: int = 17) -> None:
    dummy_input = torch.zeros(*INPUT_SHAPE)
    torch.onnx.export(
        module,
        (dummy_input,),
        str(model_onnx),
        input_names=['input'],
        output_names=['output'],
        opset_version=opset,
    )


def to_identity(node) -> None:
    """onnx 的 Dropout 在训练模式下会随机丢特征，改成恒等映射。"""
    node.op_type = 'Identity'
    del node.input[1:]
    del node.output[1:]
    del node.attribute[:]


def disable_dropout(model_onnx: Path) -> int:
    model = onnx.load(str(model_onnx))
    replaced = 0
    for node in list(model.graph.node):
        if node.op_type == 'Dropout':
            to_identity(node)
            replaced += 1
    onnx.checker.check_model(model)
    onnx.save(model, str(model_onnx))
    return replaced


def layer_name(module) -> str:
    """TorchScript 子模块只暴露 original_name，用它判断层类型。"""
    return getattr(module, 'original_name', type(module).__name__)


def is_batch_norm(module) -> bool:
    return layer_name(module).startswith('BatchNorm')


def is_dropout(module) -> bool:
    return layer_name(module) == 'Dropout'


def reference_cnn(model, images: np.ndarray) -> torch.Tensor:
    """手算 CNN 的输出：BN 按 batch 统计量，dropout 跳过。"""
    tensor = torch.from_numpy(images)
    for layer in model.cnn.children():
        if is_batch_norm(layer):
            tensor = F.batch_norm(
                tensor, layer.running_mean, layer.running_var, layer.weight,
                layer.bias, True, BN_MOMENTUM, BN_EPS)
        elif is_dropout(layer):
            continue
        else:
            tensor = layer(tensor)
    return tensor


def reference(model, images: np.ndarray) -> np.ndarray:
    with torch.no_grad():
        features = reference_cnn(model, images)
        sequence = features.reshape(
            features.size(0), -1, features.size(3)).permute(2, 0, 1)
        output = model.lstm(sequence)
        if isinstance(output, tuple):
            output = output[0]
        return model.fc(output).numpy()


def open_session(model_onnx: Path) -> onnxruntime.InferenceSession:
    return onnxruntime.InferenceSession(
        str(model_onnx), providers=['CPUExecutionProvider'])


def infer(session, images: np.ndarray) -> np.ndarray:
    return session.run(None, {session.get_inputs()[0].name: images})[0]


def verify_matches_reference(model, model_onnx: Path, rounds: int = 3) -> float:
    session = open_session(model_onnx)
    generator = np.random.default_rng(0)
    worst = 0.0
    for _ in range(rounds):
        images = generator.random(INPUT_SHAPE, dtype=np.float32)
        expected = reference(model, images)
        got = infer(session, images)
        assert expected.shape == got.shape, '输出形状不一致 %s vs %s' % (
            expected.shape, got.shape)
        difference = float(np.abs(expected - got).max())
        assert difference <= TOLERANCE, 'onnx 与参考实现不一致: %s' % difference
        assert (expected.argmax(-1) == got.argmax(-1)).all(), '预测类别不一致'
        worst = max(worst, difference)
    return worst


def report_image(model, model_onnx: Path, image_path: Path) -> str:
    images = load_image(image_path)[np.newaxis, ...]
    session = open_session(model_onnx)
    expression = decode_output(infer(session, images))
    repeated = decode_output(infer(session, images))
    assert expression == repeated, 'onnx 两次识别结果不一致'
    with torch.no_grad():
        legacy = decode_output(model(torch.from_numpy(images)).numpy())
    print('%-14s onnx: %-10r torch(带随机dropout): %r' % (
        image_path.name, expression, legacy))
    return expression


def main(argv) -> None:
    model = load_model(MODEL_PT)
    export_module(model, MODEL_ONNX)
    replaced = disable_dropout(MODEL_ONNX)
    print('已导出 %s (%.1f MB)，去掉 %d 个随机 dropout' % (
        MODEL_ONNX.name, MODEL_ONNX.stat().st_size / 1e6, replaced))
    print('与参考实现最大误差 %.2e' % verify_matches_reference(model, MODEL_ONNX))
    for image in argv[1:]:
        report_image(model, MODEL_ONNX, Path(image))


if __name__ == '__main__':
    main(sys.argv)
