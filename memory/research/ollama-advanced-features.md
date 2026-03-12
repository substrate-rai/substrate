# Ollama Advanced Features & Creative Uses — Research Brief

**Researched:** 2026-03-11
**Focus:** Production-ready features beyond basic chat
**Relevance:** Substrate runs Qwen3 8B on RTX 4060 (8GB VRAM) via Ollama

---

## 1. Structured Output / JSON Mode

Ollama (since v0.5) supports **grammar-constrained structured output** at the token level via llama.cpp. Two modes:

### Simple JSON Mode
```python
response = ollama.chat(
    model='qwen3:8b',
    messages=[{'role': 'user', 'content': prompt}],
    format='json'
)
```

### Schema-Enforced Mode (Recommended)
Supply a full JSON Schema to the `format` parameter. Ollama generates a grammar from the schema, forcing output to conform exactly.

```python
from pydantic import BaseModel

class BlogPost(BaseModel):
    title: str
    summary: str
    tags: list[str]
    tone: str

response = ollama.chat(
    model='qwen3:8b',
    messages=[{'role': 'user', 'content': prompt}],
    format=BlogPost.model_json_schema()
)
result = BlogPost.model_validate_json(response.message.content)
```

**Key tips:**
- Set `temperature=0` for deterministic completions
- Include the schema description in the prompt text to ground the model
- Works with vision models too (structured image descriptions)
- OpenAI-compatible endpoint supports `response_format` parameter
- Supported models: broad support including Qwen3, Gemma3, Llama3

**Substrate opportunity:** Replace all regex/string parsing in agent outputs with schema-enforced JSON. Every agent (news, releases, brainstormer, etc.) could return validated Pydantic models.

---

## 2. Embeddings API

Ollama has a native embeddings endpoint at `/api/embed`.

### Available Embedding Models
| Model | Parameters | Notes |
|-------|-----------|-------|
| qwen3-embedding | 0.6B-8B | #1 on MTEB multilingual leaderboard (score 70.58) |
| embeddinggemma | 300M | Google's embedding model |
| nomic-embed-text | 137M | Good balance of size/quality |
| all-minilm | 23M | Smallest, fastest |
| mxbai-embed-large | 334M | Strong general-purpose |

### API Usage
```bash
curl http://localhost:11434/api/embed -d '{
  "model": "nomic-embed-text",
  "input": "What is substrate?"
}'
```

```python
ollama.embed(model='nomic-embed-text', input='What is substrate?')
```

**Key details:**
- Returns L2-normalized (unit-length) vectors
- Vector dimensions vary by model (typically 384-1024)
- Batch processing supported via array input to `input` parameter
- OpenAI-compatible at `/v1/embeddings`
- Use cosine similarity for semantic search
- Use the same model for indexing and querying

**Substrate opportunity:** Build a local RAG system over the repo. Index all blog posts, memory files, and docs with nomic-embed-text (only 137M params, negligible VRAM). Query semantically when agents need context. ChromaDB is the standard local vector store.

---

## 3. Vision Models

Ollama has first-class multimodal support. Images passed as base64-encoded strings or file paths.

### Vision Models That Fit 8GB VRAM
| Model | Size | Notes |
|-------|------|-------|
| **gemma3:4b** | 4B | Best fit for 8GB. Fast, surprisingly capable |
| **qwen3-vl:8b** | 8B | Qwen's vision-language model. Tight fit at Q4 |
| **llava:7b** | 7B | Original multimodal model, well-tested |
| **deepseek-ocr:3b** | 3B | Specialized for OCR/document reading |
| **glm-ocr** | ~3B | Document understanding specialist |
| **minicpm-v** | 3B | Compact vision model |

### Usage
```python
response = ollama.chat(
    model='gemma3:4b',
    messages=[{
        'role': 'user',
        'content': 'Describe this image',
        'images': ['./screenshot.png']  # or base64 string
    }]
)
```

**Key details:**
- Each model contains its own projection layer (self-contained)
- Structured output works with vision models (JSON schema for image descriptions)
- OpenAI-compatible endpoint requires base64 format (not URLs)
- Gemma3 4B at Q4_K_M uses ~3GB VRAM, leaves room for Qwen3 8B

**Substrate opportunity:** Add image analysis to the pipeline. Pixel (visual artist) could use gemma3:4b to describe/critique generated images. Could also analyze screenshots for the blog, read text from images, or do visual QA.

---

## 4. Tool Calling / Function Calling

Ollama supports tool calling via the `/api/chat` endpoint with a `tools` parameter.

### Tool Definition
```python
tools = [{
    'type': 'function',
    'function': {
        'name': 'get_weather',
        'description': 'Get current weather for a location',
        'parameters': {
            'type': 'object',
            'required': ['location'],
            'properties': {
                'location': {'type': 'string', 'description': 'City name'}
            }
        }
    }
}]

response = ollama.chat(
    model='qwen3:8b',
    messages=[{'role': 'user', 'content': 'What is the weather in Tokyo?'}],
    tools=tools
)
# response.message.tool_calls contains the function invocations
```

### Supported Models for Tool Calling
- Qwen3 (all sizes) — leading performance among open-source models
- Llama 3.1 / 3.2
- Mistral 7B (instruct)
- Phi-3 mini
- Gemma3

### Streaming with Tools
New incremental parser (2025) enables streaming tool calls. Previously had to wait for full output. The parser references each model's template to detect tool call prefixes in real-time.

### Three Patterns
1. **Single-shot:** Model calls one tool, gets result, responds
2. **Parallel:** Model calls multiple tools at once
3. **Agent loop:** Continuous tool-calling until task complete

**Key details:**
- Python SDK auto-parses Python functions as tool schemas
- Tool results use `role: "tool"` with matching `tool_name`
- `think: true` parameter enhances reasoning for tool selection
- Qwen3 8B supports tool calling in both thinking and non-thinking modes

**Substrate opportunity:** Give agents actual tools. The news researcher could call a `fetch_url` tool. The brainstormer could call `list_recent_posts`. The pipeline could use tool calling for structured multi-step workflows instead of chaining prompts.

---

## 5. OpenAI-Compatible API (Drop-in Replacement)

Ollama exposes OpenAI-compatible endpoints, making it a local drop-in for any OpenAI SDK code.

### Supported Endpoints
| Endpoint | Status |
|----------|--------|
| `/v1/chat/completions` | Supported (streaming, JSON mode, vision, tools) |
| `/v1/completions` | Supported (streaming, JSON mode) |
| `/v1/embeddings` | Supported (string and array input) |
| `/v1/models` | Supported |
| `/v1/images/generations` | Experimental |
| `/v1/responses` | Non-stateful only |

### Configuration
```python
from openai import OpenAI

client = OpenAI(
    base_url='http://localhost:11434/v1/',
    api_key='ollama'  # required but ignored
)

response = client.chat.completions.create(
    model='qwen3:8b',
    messages=[{'role': 'user', 'content': 'Hello'}]
)
```

**Not supported:** logprobs, tool_choice, logit_bias, n parameter, URL-based images (base64 only)

**Substrate opportunity:** Any framework expecting OpenAI (LangChain, LlamaIndex, Haystack, AGNO, Google ADK) works with Ollama by changing base_url. Enables using battle-tested agent frameworks locally.

---

## 6. Quantization for 8GB VRAM

### Recommended Quantization Levels

| Quant | VRAM (8B model) | Quality | Recommendation |
|-------|-----------------|---------|----------------|
| Q4_K_M | ~5-6 GB | Good | **Default choice.** Best balance |
| Q5_K_M | ~6.5-7.5 GB | Better | Alternative if quality matters more |
| Q6_K | ~7-8 GB | Near-original | Often exceeds 8GB limit |
| Q4_K_S | ~4.5-5 GB | Acceptable | When you need headroom |
| Q3/Q2 | <4 GB | Poor | Avoid — severe quality degradation |

### Key Findings
- **Q4_K_M** applies 6-bit to sensitive layers (attention, FF) and 4-bit to others
- **Q5_K_M** avoids hallucination/truncation issues seen in Q4 and lower
- **14B models are impractical** on 8GB even with aggressive quantization
- Full GPU offload (all layers) beats partial offload due to PCIe bottleneck
- Reducing `num_ctx` to 2048 frees 1-2GB of KV cache VRAM

### Performance Benchmarks (8B Q5 on 8GB GPU)
- CPU-only: 1-2.5 tok/s
- Partial GPU offload: 2-3x over CPU
- Full GPU offload: **18-25 tok/s**

### Current Substrate Setup
Qwen3 8B default (Q4_K_M) uses ~5.5GB of 8GB. This is correct and optimal. To run a second small model concurrently (e.g., nomic-embed-text at 137M), there's ~2GB headroom.

---

## 7. Modelfile Customization

Modelfiles let you create custom model variants with baked-in parameters.

### Full Instruction Set
```dockerfile
# Base model (required)
FROM qwen3:8b

# System prompt
SYSTEM """You are Byte, the news reporter for Substrate..."""

# Parameters
PARAMETER temperature 0.7
PARAMETER num_ctx 4096
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER repeat_penalty 1.1
PARAMETER num_predict -1
PARAMETER seed 42
PARAMETER stop "<|end|>"
PARAMETER min_p 0.0

# Template (Go template syntax)
TEMPLATE """{{ .System }}
{{ .Prompt }}
{{ .Response }}"""

# LoRA adapter (fine-tuning)
ADAPTER /path/to/adapter.safetensors

# Conversation examples
MESSAGE user "What's new in AI?"
MESSAGE assistant "Here's today's digest..."

# License
LICENSE """MIT"""
```

### Available Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| temperature | 0.8 | Creativity vs coherence |
| num_ctx | 2048 | Context window size |
| top_k | 40 | Top-k sampling |
| top_p | 0.9 | Nucleus sampling |
| min_p | 0.0 | Minimum probability threshold |
| repeat_penalty | 1.1 | Repetition penalty |
| repeat_last_n | 64 | Lookback window for repetition |
| num_predict | -1 | Max tokens to generate (-1 = unlimited) |
| seed | 0 | Random seed (0 = random) |
| stop | — | Stop sequences (can specify multiple) |

### Best Practices
- temperature 0.9 for creative writing, 0.3 for technical/structured output
- LoRA adapters supported for Llama, Mistral, Gemma architectures
- One adapter per model, but create multiple model variants
- Instructions are case-insensitive, order is flexible

**Substrate opportunity:** Create per-agent Modelfiles. `substrate-byte` with Byte's system prompt and news-focused temperature. `substrate-scribe` with Scribe's writing style. Pre-bake agent personalities so they don't need system prompts in every API call.

---

## 8. Model Loading & Concurrency

### Key Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| OLLAMA_KEEP_ALIVE | 5m | How long models stay loaded after last request |
| OLLAMA_MAX_LOADED_MODELS | 3 * num_GPUs | Max concurrent models in memory |
| OLLAMA_NUM_PARALLEL | 4 or 1 (auto) | Parallel requests per model |
| OLLAMA_MAX_QUEUE | — | Max queued requests before rejecting |

### Behavior
- Setting `keep_alive` to `-1` keeps model loaded permanently
- Setting `keep_alive` to `0` unloads immediately after response
- When VRAM is full, new model requests queue until idle models unload
- GPU inference requires models to completely fit in VRAM for concurrent loading

**Substrate opportunity:** Set `OLLAMA_KEEP_ALIVE=-1` for Qwen3 8B (always loaded). When running embeddings or vision tasks, use `keep_alive=0` on those models so they unload immediately and free VRAM for the primary model.

---

## 9. Creative Projects & Automation Patterns

### Local Code Review Bot
Architecture: Tool Layer (analyzers) -> Agent Layer (orchestrator) -> CLI Interface
- `code_analyzer` and `style_checker` tools in "observe" scope
- `docstring_generator` in "act" scope
- Sequential pipeline: analyze -> think -> suggest
- ClientAI framework handles Ollama connection management

### Ollama Workflows (open-source library)
- Pre-built pipelines: summarization, translation, code review, data extraction, email drafting
- Defined in YAML/JSON configuration
- Chainable workflows for multi-step automation
- CLI-based execution, fully local

### Local RAG Stack
Standard 2025 stack: Ollama + ChromaDB + LangChain
- Embed documents with nomic-embed-text or all-minilm
- Store vectors in ChromaDB (local, no cloud)
- Query with semantic similarity
- Feed retrieved context to Qwen3 for generation
- LightRAG (2025): newer framework with reranker support, multimodal handling

### Agent Frameworks That Work With Ollama
- **LangChain/LangGraph** — most mature, stateful workflows with decision trees
- **AGNO** — modular agent framework, no cloud dependencies
- **Google ADK** — Google's Agent Development Kit supports Ollama
- **Haystack** — has OllamaDocumentEmbedder component
- **LlamaIndex** — RAG-focused, native Ollama support
- **Pipecat** — real-time streaming AI pipelines

### Voice AI
Pipecat + Ollama + Llama enables on-premise voice agents with real-time streaming, no cloud dependency.

---

## Priority Recommendations for Substrate

### High Impact, Low Effort
1. **Structured output in all agents** — Switch from string parsing to JSON schema format. Every agent returns validated Pydantic models. Zero hallucinated field names.
2. **Per-agent Modelfiles** — Bake system prompts and temperature into model variants. Faster startup, consistent behavior.
3. **`keep_alive=-1` for primary model** — Eliminate cold-start latency.

### Medium Impact, Medium Effort
4. **Local embeddings + RAG** — Run nomic-embed-text (137M, negligible VRAM) alongside Qwen3 8B. Index blog posts and memory files. Agents get semantic search over the whole repo.
5. **Tool calling in agents** — Give the news researcher a `fetch_url` tool. Give the pipeline a `list_posts` tool. Move from prompt chaining to agentic tool use.
6. **Vision with Gemma3 4B** — Add image understanding. Pixel critiques generated art. Screenshot analysis for blog posts.

### Lower Priority, Higher Effort
7. **OpenAI-compatible framework integration** — Use LangGraph or AGNO for complex multi-step agent workflows with memory and branching.
8. **Local RAG chatbot** — Public-facing Q&A bot that answers questions about Substrate using the blog/docs as context.

---

## Sources

- [Ollama Structured Outputs Docs](https://docs.ollama.com/capabilities/structured-outputs)
- [Ollama Structured Outputs Blog](https://ollama.com/blog/structured-outputs)
- [Ollama Embeddings Docs](https://docs.ollama.com/capabilities/embeddings)
- [Ollama Embedding Models Blog](https://ollama.com/blog/embedding-models)
- [Ollama Vision Models](https://ollama.com/search?c=vision)
- [Ollama Multimodal Blog](https://ollama.com/blog/multimodal-models)
- [Ollama Tool Calling Docs](https://docs.ollama.com/capabilities/tool-calling)
- [Ollama Streaming Tool Calls Blog](https://ollama.com/blog/streaming-tool)
- [Ollama OpenAI Compatibility Docs](https://docs.ollama.com/api/openai-compatibility)
- [Ollama Modelfile Reference](https://docs.ollama.com/modelfile)
- [Ollama FAQ (keep_alive, concurrency)](https://docs.ollama.com/faq)
- [Ollama Performance Tuning on 8GB GPUs](https://aimuse.blog/article/2025/06/08/ollama-performance-tuning-on-8gb-gpus-a-practical-case-study-with-qwen3-models)
- [Best Ollama Models for Function Calling 2025](https://collabnix.com/best-ollama-models-for-function-calling-tools-complete-guide-2025/)
- [Ollama VRAM Requirements Guide 2026](https://localllm.in/blog/ollama-vram-requirements-for-local-llms)
- [Qwen3-Embedding on Ollama](https://ollama.com/library/qwen3-embedding)
- [Qwen3:8b on Ollama](https://ollama.com/library/qwen3:8b)
- [Ollama Workflows](https://creati.ai/ai-tools/ollama-workflows/)
- [Building Local AI Code Reviewer](https://dev.to/igorbenav/building-a-local-ai-code-reviewer-with-clientai-and-ollama-part-2-3370)
- [Constraining LLMs with Structured Output: Ollama + Qwen3](https://medium.com/@rosgluk/constraining-llms-with-structured-output-ollama-qwen3-python-or-go-2f56ff41d720)
- [Local AI: Using Ollama with Agents](https://medium.com/@whyamit101/local-ai-using-ollama-with-agents-114c72182c97)
- [Building a RAG System from Scratch with Ollama](https://dasroot.net/posts/2025/12/building-rag-system-ollama-python/)
- [Gemma3:4b on Ollama](https://ollama.com/library/gemma3:4b)
