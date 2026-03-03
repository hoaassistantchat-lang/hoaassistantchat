# HOA Assistant - AI-Powered Q&A System

An intelligent HOA (Homeowners Association) assistant that uses RAG (Retrieval-Augmented Generation) to answer resident questions, manage tickets, and provide 24/7 support.

## Features

- 🤖 AI-powered Q&A using Claude (Anthropic)
- 📄 Document ingestion and processing (PDF support)
- 🔍 Vector-based semantic search with pgvector
- 🎫 Ticket management system
- 💬 Conversation history tracking
- 🌐 Multi-language support (English/Spanish)
- 📚 FAQ management

## Tech Stack

- **Backend**: Java 21, Spring Boot 3.2.2
- **Database**: PostgreSQL with pgvector extension
- **AI/LLM**: Claude (Anthropic API)
- **Embeddings**: OpenAI text-embedding-3-small
- **PDF Processing**: Apache PDFBox
- **Build Tool**: Maven

## Prerequisites

- Java 21 ✅ (You have this)
- Maven 3.9+ ✅ (You have this)
- Docker Desktop ✅ (You have this)
- Anthropic API Key (Sign up at https://console.anthropic.com/)
- OpenAI API Key (Sign up at https://platform.openai.com/)

## Quick Start

### 1. Start PostgreSQL with Docker

```bash
cd hoa-assistant
docker-compose up -d
```

This will start PostgreSQL with the pgvector extension and automatically create the database schema.

### 2. Configure API Keys

Edit `src/main/resources/application.yml` and add your API keys:

```yaml
hoa:
  api:
    anthropic:
      api-key: YOUR_ANTHROPIC_API_KEY_HERE
    openai:
      api-key: YOUR_OPENAI_API_KEY_HERE
```

Alternatively, set environment variables:
```bash
export ANTHROPIC_API_KEY=your-key-here
export OPENAI_API_KEY=your-key-here
```

For local development, you can also use a root `.env.local` file:
1. Copy `.env.example` to `.env.local`
2. Fill in your Supabase and API credentials
3. Run `./run-local.ps1` (PowerShell)

### 3. Build and Run

```bash
mvn clean install
mvn spring-boot:run
```

The application will start on `http://localhost:8080`

### 4. Test the API

**Health Check:**
```bash
curl http://localhost:8080/api/chat/health
```

**Send a Chat Message:**
```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are the pool hours?",
    "communityId": 1
  }'
```

## Project Structure

```
hoa-assistant/
├── src/main/java/com/hoa/assistant/
│   ├── HoaAssistantApplication.java      # Main application
│   ├── config/
│   │   ├── HoaProperties.java            # Configuration properties
│   │   └── HttpClientConfig.java         # HTTP client setup
│   ├── controller/
│   │   ├── ChatController.java           # Chat endpoints
│   │   ├── DocumentController.java       # Document upload/management
│   │   └── TicketController.java         # Ticket management
│   ├── service/
│   │   ├── ChatService.java              # Chat orchestration
│   │   ├── ClaudeService.java            # Claude API integration
│   │   ├── DocumentService.java          # PDF processing
│   │   ├── EmbeddingService.java         # OpenAI embeddings
│   │   ├── RagService.java               # RAG implementation
│   │   └── TicketService.java            # Ticket operations
│   ├── model/                            # JPA entities
│   ├── repository/                       # Data access layer
│   └── dto/                              # Request/Response objects
├── src/main/resources/
│   ├── application.yml                   # Configuration
│   └── prompts/
│       └── system-prompt.txt             # AI system prompt
├── docker-compose.yml                    # PostgreSQL setup
├── init.sql                              # Database schema
└── pom.xml                               # Maven dependencies
```

## API Endpoints

### Chat
- `POST /api/chat` - Send a message
- `GET /api/chat/health` - Health check

### Documents
- `POST /api/documents/upload` - Upload a PDF document
- `GET /api/documents/community/{communityId}` - Get all documents
- `POST /api/documents/{documentId}/process` - Process uploaded document

### Tickets
- `POST /api/tickets` - Create a ticket
- `GET /api/tickets/community/{communityId}` - Get all tickets
- `GET /api/tickets/community/{communityId}/open` - Get open tickets
- `PATCH /api/tickets/{ticketId}/status` - Update ticket status

## Usage Examples

### Upload a Document

```bash
curl -X POST http://localhost:8080/api/documents/upload \
  -F "file=@/path/to/document.pdf" \
  -F "communityId=1" \
  -F "documentType=CC&Rs"
```

### Create a Ticket

```bash
curl -X POST http://localhost:8080/api/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "communityId": 1,
    "ticketType": "maintenance",
    "description": "Pool pump is making noise",
    "location": "Community Pool",
    "priority": "normal"
  }'
```

### Chat with Context

```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Can I park my RV in the driveway?",
    "communityId": 1,
    "sessionId": "optional-session-id"
  }'
```

## Database Schema

The application uses the following main tables:
- `communities` - HOA community information
- `documents` - Uploaded documents
- `document_chunks` - Document chunks with vector embeddings
- `tickets` - Support tickets
- `conversations` - Chat sessions
- `messages` - Chat message history
- `faqs` - Frequently asked questions

## Configuration

Edit `application.yml` to customize:

```yaml
hoa:
  documents:
    provider: local                         # local | s3
    storage-path: /path/to/store/documents  # Used when provider=local
    chunk-size: 800                          # Text chunk size for embeddings
    chunk-overlap: 100                       # Overlap between chunks
    s3-bucket: hoa-docs-prod                 # Used when provider=s3
    s3-region: us-east-1
    s3-prefix: documents
    s3-endpoint: ""                          # Optional S3-compatible endpoint
    s3-path-style: false
  
  rag:
    top-k: 4                                # Number of chunks to retrieve
    confidence-threshold: 0.75              # Escalation threshold
```

S3 configuration can also be supplied via env vars:
`HOA_DOCUMENTS_PROVIDER`, `HOA_S3_BUCKET`, `HOA_S3_REGION`, `HOA_S3_PREFIX`, `HOA_S3_ENDPOINT`, `HOA_S3_PATH_STYLE`.

## Development

### Run in IntelliJ IDEA

1. Open IntelliJ IDEA
2. File → Open → Select `hoa-assistant` folder
3. Wait for Maven to download dependencies
4. Configure API keys in `application.yml`
5. Run `HoaAssistantApplication.java`

### Database Access

PostgreSQL is running in Docker:
- Host: localhost
- Port: 5432
- Database: hoa_assistant
- Username: hoa_user
- Password: hoa_password

Connect using any PostgreSQL client or:
```bash
docker exec -it hoa-postgres psql -U hoa_user -d hoa_assistant
```

## Troubleshooting

### Port 5432 already in use
```bash
# Stop the container
docker-compose down

# Find process using port 5432
netstat -ano | findstr :5432

# Kill the process or change port in docker-compose.yml
```

### Maven build fails
```bash
# Clean and rebuild
mvn clean install -U
```

### API keys not working
- Verify keys are correct in `application.yml`
- Or set as environment variables
- Restart the application after changing keys

## Next Steps

1. **Add Frontend**: Build a React/Vue frontend for better user experience
2. **Add Authentication**: Implement Spring Security for user management
3. **Async Processing**: Use Spring @Async for document processing
4. **Caching**: Add Redis for caching frequently accessed data
5. **Monitoring**: Integrate with Prometheus/Grafana
6. **Testing**: Add unit and integration tests

## License

MIT

## Support

For issues or questions, create an issue in the repository.
