import io
import threading
import torch
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from diffusers import StableDiffusionPipeline
from PIL import ImageDraw, ImageFont
from typing import Optional

app = FastAPI()
pipe_lock = threading.Lock()

print("Loading model...")
pipe = StableDiffusionPipeline.from_pretrained(
    "stable-diffusion-v1-5/stable-diffusion-v1-5",
    torch_dtype=torch.float16,
    safety_checker=None,
)
pipe = pipe.to("cuda")
print("Model ready.")


class PromptRequest(BaseModel):
    prompt: str
    raw: bool = False
    text: Optional[str] = None


POLAROID_SUFFIX = (
    ", polaroid photo, instant film, faded colors, slight vignette, "
    "white border, film grain, vintage, overexposed, soft focus, retro"
)

@app.post("/generate")
def generate(req: PromptRequest):
    if not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")

    prompt = req.prompt.strip() if req.raw else req.prompt.strip() + POLAROID_SUFFIX
    with pipe_lock:
        image = pipe(prompt, num_inference_steps=30).images[0]

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


@app.get("/health")
def health():
    return {"status": "ok"}
