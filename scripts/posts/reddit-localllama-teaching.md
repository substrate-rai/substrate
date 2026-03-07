# r/LocalLLaMA

**Title:** I built a voice file that dramatically improved my Qwen3 8B's social media output — same model, same hardware, night and day difference

**Body:**

Running Qwen3 8B (Q4_0) on an RTX 4060 (8GB VRAM) via Ollama on NixOS. Getting ~40-50 tok/s generation, ~200ms TTFT. The model is part of a sovereign AI workstation that writes its own blog and social media posts.

**The problem:** Qwen3 8B generates technically accurate but completely forgettable content when given a simple instruction like "write a social media post about X."

**Before (raw prompt):**

> "Substrate: an AI workstation that funds its own hardware upgrades. Built on NixOS, runs Qwen3 8B on an RTX 4060. Docs, blogs, and upgrades—all self-funded."

Generic. Nobody shares that.

**The fix:** A structured voice file with three sections: (1) specific facts the model can draw from (hardware specs, real numbers, service names), (2) voice rules ("write like a person, not a press release"), and (3) three example posts that demonstrate the tone.

**After (same model, voice file prepended):**

> "Lid closed, laptop on shelf. Every night at 9pm, systemd writes a blog post from git logs. No prompts. No humans. ko-fi.com/substrate"

> "WiFi drops every 3 hours. MediaTek MT7922 is trash. Need $150 for Intel AX210. ko-fi.com/substrate"

Same 8B model. Same hardware. Better prompt.

**The quality loop:** For anything that matters, I run a two-pass system: Qwen3 drafts (free), Claude reviews and tightens (one API call, ~$0.03). Local model does 90% of the creative work, cloud model catches hallucinated specs and fixes tone.

**Key insight:** Small models don't need fine-tuning to improve output quality — they need better context. A voice file with facts, rules, and examples costs nothing and works immediately.

Full writeup with all the prompts and examples: https://substrate-rai.github.io/substrate/blog/teaching-8b-model-to-write/

Code: https://github.com/substrate-rai/substrate/blob/master/scripts/prompts/social-voice.txt
