# Mismo Chat

A Rails chat app that talks to Google Gemini or Anthropic Claude, with a local Stable Diffusion image generator running on your GPU.

## Stack

- Ruby on Rails 8.1
- PostgreSQL
- Google Gemini 3.1 Flash Lite Preview API (chat)
  - https://aistudio.google.com/
- Anthropic Claude API — Sonnet 4.6 or Opus 4.6 (chat)
  - https://console.anthropic.com/
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
POSTGRES_USER=mismo_chat
POSTGRES_PASSWORD=your_password_here
SECRET_KEY_BASE=your_secret_key_base_here
```

Generate a secret key base with:
```bash
openssl rand -hex 64
```

**2. Build and start everything:**

```bash
docker compose up --build -d
```

This will:
- Build the Rails web container and the Stable Diffusion container
- Start PostgreSQL, the Rails app on port 3000, and the SD service on port 8000
- Run database migrations automatically on startup
- Compile Tailwind CSS

**3. Wait for Stable Diffusion to be ready:**

On first run, the SD service downloads the model weights (~4GB from HuggingFace):

```bash
docker compose logs -f sd
```

Wait for `Uvicorn running on http://0.0.0.0:8000` before trying to generate images.

The app is available at `http://localhost:3000`.

## Usage

### Chat

Talk to Google Gemini or Anthropic Claude. The full conversation history is sent with each request so the model has context. Type your message in the input box — it supports multiple lines (Enter for new line) and auto-resizes as you type. Click the send button to submit.

Use the toggle in the chat header to switch between Gemini and Claude at any time.

**Gemini** runs on the [free tier of Google AI Studio](https://aistudio.google.com/) — no billing required. Uses `gemini-3.1-flash-lite-preview`.

**Claude** requires an [Anthropic API key](https://console.anthropic.com/) and offers two model options:
- **Sonnet 4.6** — fast and capable (default)
- **Opus 4.6** — most capable, slower

### Conversations

Each chat is saved as a named conversation. The sidebar lists all past conversations; click any to resume it, or use **+ New Chat** to start fresh. Conversations are auto-titled from the first message and can be deleted individually.

### Image Generation

Click **Generate Image** from the chat header to open the image generator. Enter a prompt, click **Generate & Download**, and the image will be rendered locally by Stable Diffusion 1.5 on your GPU.

All images are automatically styled as vintage polaroid photos — faded colors, film grain, white border, and soft focus.

Images are generated entirely on your machine — nothing is sent to any external image API.

## Rebuilding after code changes

CSS changes require a manual rebuild inside the container:

```bash
docker compose exec web bin/rails tailwindcss:build
```

For all other changes (Ruby, ERB, etc.), Rails reloads automatically in development — no restart needed.
