import io
import threading
import torch
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from diffusers import StableDiffusion3Pipeline
from PIL import ImageDraw, ImageFont, ImageFilter, ImageEnhance
from typing import Optional

app = FastAPI()
pipe_lock = threading.Lock()

DEFAULT_NEGATIVE = (
    "blurry, low quality, deformed, ugly, bad anatomy, watermark, "
    "text, signature, jpeg artifacts, oversaturated, distorted"
)

print("Loading model...")
pipe = StableDiffusion3Pipeline.from_pretrained(
    "stabilityai/stable-diffusion-3.5-medium",
    torch_dtype=torch.bfloat16,
)
pipe = pipe.to("cuda")
pipe.enable_vae_slicing()
pipe.enable_vae_tiling()
print("Model ready.")


class PromptRequest(BaseModel):
    prompt: str
    text: Optional[str] = None
    negative_prompt: Optional[str] = None
    guidance_scale: float = 4.5
    num_inference_steps: int = 28
    width: Optional[int] = None
    height: Optional[int] = None


@app.post("/generate")
def generate(req: PromptRequest):
    if not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")

    prompt = req.prompt.strip()
    negative_prompt = req.negative_prompt or DEFAULT_NEGATIVE
    with pipe_lock:
        image = pipe(
            prompt,
            negative_prompt=negative_prompt,
            num_inference_steps=req.num_inference_steps,
            guidance_scale=req.guidance_scale,
            width=req.width,
            height=req.height,
        ).images[0]

    torch.cuda.empty_cache()

    if req.text:
        from PIL import Image as PILImage
        draw = ImageDraw.Draw(image)
        w, h = image.size
        # Scale font to fit width with some padding
        font_size = 80
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
        except Exception:
            font = ImageFont.load_default()
        # Shrink font until text fits within 90% of image width
        while font_size > 12:
            bbox = draw.textbbox((0, 0), req.text, font=font)
            tw = bbox[2] - bbox[0]
            if tw <= w * 0.9:
                break
            font_size -= 4
            try:
                font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
            except Exception:
                break
        bbox = draw.textbbox((0, 0), req.text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        x, y = (w - tw) // 2, h - th - 20
        # Dark shadow for contrast
        for dx, dy in [(-2,-2),(2,-2),(-2,2),(2,2),(0,3),(3,0),(-3,0),(0,-3)]:
            draw.text((x + dx, y + dy), req.text, font=font, fill=(0, 0, 0))
        draw.text((x, y), req.text, font=font, fill=(255, 255, 255))

    buf = io.BytesIO()
    image.save(buf, format="PNG")
    buf.seek(0)

    return Response(content=buf.read(), media_type="image/png")


@app.post("/generate/header")
def generate_header(req: PromptRequest):
    if not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")

    with pipe_lock:
        image = pipe(
            req.prompt.strip(),
            negative_prompt=DEFAULT_NEGATIVE,
            num_inference_steps=30,
            guidance_scale=7.5,
        ).images[0]

    # Upscale
    image = image.resize((2048, 2048), resample=5)  # LANCZOS

    # Grayscale to match dark UI theme
    image = image.convert("L").convert("RGB")

    # Denoise then sharpen
    image = image.filter(ImageFilter.GaussianBlur(radius=0.6))
    image = image.filter(ImageFilter.UnsharpMask(radius=2, percent=160, threshold=2))

    # Boost contrast
    image = ImageEnhance.Contrast(image).enhance(1.4)

    # Crop middle section — tower + cables + some walkway
    w, h = image.size
    target_h = 500
    top = int(h * 0.35)
    image = image.crop((0, top, w, top + target_h))

    buf = io.BytesIO()
    image.save(buf, format="PNG")
    buf.seek(0)
    return Response(content=buf.read(), media_type="image/png")


@app.get("/health")
def health():
    return {"status": "ok"}
