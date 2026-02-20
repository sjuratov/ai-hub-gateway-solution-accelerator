"""
Microsoft Agent Framework - Hello World Example
Uses Azure AI Foundry gpt-4o behind APIM gateway
"""
import os
import asyncio
import logging
from openai import AsyncOpenAI
from agent_framework import ChatAgent
from agent_framework.openai import OpenAIChatClient

# Enable detailed HTTP logging
logging.basicConfig(level=logging.DEBUG)
# Enable httpx request/response logging (used by OpenAI client)
logging.getLogger("httpx").setLevel(logging.DEBUG)
logging.getLogger("openai").setLevel(logging.DEBUG)


async def main():
    # APIM Configuration
    apim_endpoint = "https://apim-bc2yajbbxycfw.azure-api.net/models"
    api_key = os.getenv("APIM_API_KEY")
    if not api_key:
        raise ValueError("APIM_API_KEY environment variable is required")
    api_version = "2024-05-01-preview"
    model_name = "gpt-4o"
    
    # Create underlying OpenAI client so we can set default query parameters
    openai_client = AsyncOpenAI(
        base_url=apim_endpoint,
        api_key=api_key,
        default_query={"api-version": api_version},
        default_headers={
            "api-key": api_key  # APIM expects 'api-key' header
        },
    )

    # Create OpenAI Chat Client using the supported async_client parameter
    client = OpenAIChatClient(
        model_id=model_name,
        async_client=openai_client,
    )
    
    # Create Chat Agent
    agent = ChatAgent(
        chat_client=client,
        name="HelloWorldAgent",
        instructions="You are a helpful AI assistant. Be concise and friendly."
    )
    
    # Get a new conversation thread
    thread = agent.get_new_thread()
    
    # Send message and get response
    print("🤖 Sending message to agent...")
    result = await agent.run("Hello! Can you introduce yourself?", thread=thread)
    
    # Extract response content
    response_text = result.text if hasattr(result, 'text') else str(result)
    
    print(f"\n💬 Agent response:\n{response_text}\n")
    print("✅ Hello World completed!")


if __name__ == "__main__":
    asyncio.run(main())
