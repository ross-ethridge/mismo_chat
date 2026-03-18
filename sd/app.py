import io
import torch
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from diffusers import StableDiffusionPipeline

app = FastAPI()

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


POLAROID_SUFFIX = (
    ", polaroid photo, instant film, faded colors, slight vignette, "
    "white border, film grain, vintage, overexposed, soft focus, retro"
)

@app.post("/generate")
def generate(req: PromptRequest):
    if not req.prompt.strip():
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")

    prompt = req.prompt.strip() if req.raw else req.prompt.strip() + POLAROID_SUFFIX
    image = pipe(prompt, num_inference_steps=30).images[0]

    buf = io.BytesIO()
    image.save(buf, format="PNG")
    buf.seek(0)

    return Response(content=buf.read(), media_type="image/png")


@app.get("/health")
def health():
    return {"status": "ok"}
