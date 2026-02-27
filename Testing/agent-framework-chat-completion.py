"""
Microsoft Agent Framework - Hello World Example
Uses Azure AI Foundry gpt-4o behind APIM gateway
"""
import os
import asyncio
import logging
from pathlib import Path
from dotenv import load_dotenv
from openai import AsyncOpenAI
from agent_framework import ChatAgent
from agent_framework.openai import OpenAIChatClient
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry.instrumentation.openai_v2 import OpenAIInstrumentor

# Enable detailed HTTP logging
logging.basicConfig(level=logging.DEBUG)
# Enable httpx request/response logging (used by OpenAI client)
logging.getLogger("httpx").setLevel(logging.DEBUG)
logging.getLogger("openai").setLevel(logging.DEBUG)


def configure_observability() -> None:
    connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if not connection_string:
        raise ValueError("APPLICATIONINSIGHTS_CONNECTION_STRING environment variable is required")

    configure_azure_monitor(connection_string=connection_string)
    OpenAIInstrumentor().instrument()


async def main():
    env_path = Path(__file__).resolve().parent / ".env"
    load_dotenv(dotenv_path=env_path)
    configure_observability()

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

    tracer = trace.get_tracer(__name__)
    
    # Send message and get response
    print("🤖 Sending message to agent...")
    with tracer.start_as_current_span("agent_chat_completion"):
        result = await agent.run("Hello! Can you introduce yourself?", thread=thread)
    
    # Extract response content
    response_text = result.text if hasattr(result, 'text') else str(result)
    
    print(f"\n💬 Agent response:\n{response_text}\n")
    print("✅ Hello World completed!")


if __name__ == "__main__":
    asyncio.run(main())
