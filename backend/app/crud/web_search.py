# app/crud/web_search.py
# Free web search using DuckDuckGo — no API key, no sign-up
# pip install duckduckgo-search

import asyncio


async def search_web(query: str, max_results: int = 5) -> str:
    """
    Searches the web using DuckDuckGo and returns formatted results.
    Runs the sync DuckDuckGo library in a thread pool so it doesn't
    block FastAPI's async event loop.
    Falls back gracefully if the package isn't installed.
    """
    try:
        from duckduckgo_search import DDGS

        loop = asyncio.get_event_loop()

        def _sync_search():
            # DDGS is a context manager — always use `with` to avoid leaks
            with DDGS() as ddgs:
                return list(ddgs.text(query, max_results=max_results))

        # run_in_executor moves the blocking call to a thread
        # so FastAPI stays responsive during the search
        results = await loop.run_in_executor(None, _sync_search)

        if not results:
            return f"No web results found for: {query}"

        # Format each result as a numbered entry
        formatted = []
        for i, r in enumerate(results, 1):
            title = r.get("title", "Untitled")
            body  = r.get("body", "")[:250]   # cap snippet length
            href  = r.get("href", "")
            formatted.append(f"{i}. {title}\n   {body}...\n   Source: {href}")

        return "\n\n".join(formatted)

    except ImportError:
        # Package not installed — LLM will use its own knowledge
        return "Web search unavailable. Generating from knowledge base."

    except Exception as e:
        return f"Search error: {str(e)}. Generating from knowledge base instead."