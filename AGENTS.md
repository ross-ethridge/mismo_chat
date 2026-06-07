# Agent Knowledge Base: Mismo Chat

This file provides specific technical context and architectural mapping for coding agents. Use this as the primary source of truth when navigating the codebase.

## System Overview
Mismo Chat is a Ruby on Rails 8.1 application designed as a high-end interface for LLMs (Gemini, Claude, Ollama) tailored for technical users. It supports image generation via local Stable Diffusion.

**Core Feature:** Seamlessly switches between different AI providers and handles "multimodal" logic (detecting if an AI wants to generate an image and automatically routing it to the local Stable Diffusion service).

## Key Architectural Components

### 1. Data Layer (Models)
- `app/models/conversation.rb`: Represents a chat session.
- `app/models/message.rb`: Stores content, metadata, and optional binary data (`image_data` as Base64).

### 2. Service Layer (Core Logic)
The application uses the Service Pattern to abstract external API interactions:
- `ClaudeService`: Interfaces with Anthropic (Models: **sonnet**, **opus**).
- `GeminiService`: Interfaces with Google Gemini (Model: **flash**).
- `OllamaService`: Connects to local Ollama instances. Includes helper methods for `available_models` and `running_models`.
- `ImagenService`: Communicates with the local Stable Diffusion container (port 8000) to generate images.
- `PromptEnhancerService`: A **critical intermediate step** where an LLM is used to expand a simple user prompt into a detailed Stable Diffusion-compatible prompt.

### 3. Controller Logic & Routing
- `ChatsController#create`:
    - Processes the user's message and appends it to the history.
    - Selects the correct service based on `session[:ai_model]`.
    - **Critical Logic**: After receiving a response from the AI, it checks if the message contains JSON structured for image generation (e.g., `{ "image_prompt": "...", "width": ..., "height": ... }`). If found, it automatically triggers `PromptEnhancerService` and `ImagenService`.
- `ImagesController`: Provides a standalone route for manual prompt entry to generate images directly.

## Execution Flow Map

### Chat Flow:
1. **Request**: User submits text to `ChatsController#create`.
2. **Context Preparation**: Get history from `Conversation.find(...)`.
3. **LLM Call**: Route to `ClaudeService`, `GeminiService`, or `OllamaService`.
4. **Response Parsing**: Check for `image_prompt` in the response JSON.
5. **Image Logic (Optional)**: If image prompt detected, call `PromptEnhancerService` -> `ImagenService` -> save as new `Message` with `image_data`.

### Image Generation Flow:
1. **Input**: User provides description (via UI or direct API).
2. **Enhancement**: `PromptEnhancerService` optimizes the prompt for Stable Diffusion.
3. **Generation**: `ImagenService` sends to local GPU host.
4. **Output**: Save and display resulting image.

## Key Implementation Notes
- **Environment Variables**: Managed in `.env` (Gemini keys, Anthropic keys, etc.).
- **Images**: Raw images are returned from `ImagenService` as byte strings and stored as Base64 strings in the database.
- **Prompt Templates**: Heavy lifting for "personality" is handled within the System Prompts inside the individual Service files.
