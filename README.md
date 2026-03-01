# Chingadero Chat

A Rails chat app that talks to Google Gemini or Anthropic Claude, with a local Stable Diffusion image generator running on your GPU.

## Stack

- Ruby on Rails 8.1
- PostgreSQL
- Google Gemini 2.5 Flash API (chat)
- Anthropic Claude API — Sonnet 4.6 or Opus 4.6 (chat)
- Stable Diffusion 1.5 via local FastAPI/PyTorch service (image generation)
- Docker / Docker Compose

## Requirements

- Docker and Docker Compose
- An NVIDIA GPU with the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed and configured
- A [Google AI Studio](https://aistudio.google.com/) API key (Free Tier)
- An [Anthropic](https://console.anthropic.com/) API key (optional — only needed if you want to use Claude)
- A [HuggingFace](https://huggingface.co/) account and API token (Free Tier, just so you can download Stable Diffusion)

### NVIDIA Container Toolkit (WSL2 / Linux)

Install and configure the toolkit so Docker can access your GPU:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo service docker restart
```

> **Note:** Driver version 555+ on WSL2 requires nvidia-container-toolkit v1.15.0 or newer. Older versions will fail with `Error 500: named symbol not found` when PyTorch tries to initialize CUDA.

## Setup

**1. Create a `.env` file:**

```
GEMINI_API_KEY=your_gemini_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key   # optional — only needed for Claude
HF_TOKEN=your_huggingface_token
POSTGRES_USER=chingadero_chat
POSTGRES_PASSWORD=your_password_here
SECRET_KEY_BASE=your_secret_key_base_here
```

Generate a secret key base with:
```bash
openssl rand -hex 64
```

**2. Build all images:**

```bash
docker compose -f docker-compose.prod.yaml build
```

**3. Create the database:**

```bash
docker compose -f docker-compose.prod.yaml run --rm web bin/rails db:prepare
```

**4. Start the app:**

```bash
docker compose -f docker-compose.prod.yaml up -d
```

The app runs on `http://localhost`. The Stable Diffusion service starts on port 8000 and will download the model (~4GB) on first run — check its progress with:

```bash
docker compose -f docker-compose.prod.yaml logs -f sd
```

Wait for `Uvicorn running on http://0.0.0.0:8000` before trying to generate images.

## Features

### Chat
Talk to Google Gemini 2.5 Flash or Anthropic Claude. The full conversation history is sent with each request so the model has context.

Use the toggle in the chat header to switch providers at any time — your choice is remembered for the session.

**Gemini** runs on the [free tier of Google AI Studio](https://aistudio.google.com/) — no billing setup required.

**Claude** requires an [Anthropic API key](https://console.anthropic.com/) and offers two model options selectable from the header:
- **Sonnet 4.6** — fast and capable (default)
- **Opus 4.6** — most capable, slower

### Conversations
Each chat is saved as a named conversation. The sidebar lists all past conversations; click any to resume it, or use **+ New Chat** to start fresh. Conversations are auto-titled from the first message and can be deleted individually.

### Image Generation
Click **Generate Image** from the chat header to open the image generator. Enter a prompt, click **Generate & Download**, and the image will be rendered locally by Stable Diffusion 1.5 on your GPU and displayed in the browser. A download link is provided below the image.

Images are generated entirely on your machine — nothing is sent to any external image API.
