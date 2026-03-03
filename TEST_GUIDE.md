# HOA Assistant - Testing Guide

## Prerequisites

### 1. Start PostgreSQL Database
```bash
cd hoa-assistant
docker-compose up -d
```

Verify it's running:
```bash
docker ps
```

You should see `hoa-postgres` container running.

### 2. Build the Application
```bash
mvn clean install
```

### 3. Run the Application
```bash
mvn spring-boot:run
```

Or use IntelliJ IDEA: Right-click `HoaAssistantApplication.java` → Run

The app should start on `http://localhost:8080`

---

## Testing Methods

### Method 1: Using PowerShell (Windows)

#### Health Check
```powershell
$response = Invoke-WebRequest -Uri "http://localhost:8080/api/chat/health" -Method GET
Write-Host $response.Content
```

Expected response: `Chat service is running`

#### Send a Chat Message
```powershell
$headers = @{
    "Content-Type" = "application/json"
}

$body = @{
    message = "What are the pool hours?"
    communityId = 1
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "http://localhost:8080/api/chat" `
    -Method POST `
    -Headers $headers `
    -Body $body

$response.Content | ConvertFrom-Json | ConvertTo-Json | Write-Host
```

**Note**: The first time might fail with a message about no documents - this is expected since you haven't uploaded any documents yet.

### Method 1b: Using curl (Linux/Mac/Git Bash)

#### Health Check
```bash
curl http://localhost:8080/api/chat/health
```

Expected response: Should return 200 OK (or similar status)

#### Send a Chat Message
```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are the pool hours?",
    "communityId": 1
  }'
```


---

### Method 2: Using IntelliJ HTTP Client (Recommended)

Create a file named `test.http` in your project root:

```http
### Health Check
GET http://localhost:8080/api/chat/health

### Send a Chat Message
POST http://localhost:8080/api/chat
Content-Type: application/json

{
  "message": "What are the pool hours?",
  "communityId": 1
}

### Upload a Document
POST http://localhost:8080/api/documents/upload
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW

------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="file"; filename="sample.pdf"
Content-Type: application/pdf

< /path/to/sample.pdf
------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="communityId"

1
------WebKitFormBoundary7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="documentType"

CC&Rs
------WebKitFormBoundary7MA4YWxkTrZu0gW--

### Create a Ticket
POST http://localhost:8080/api/tickets
Content-Type: application/json

{
  "communityId": 1,
  "ticketType": "maintenance",
  "description": "Pool pump is making noise",
  "location": "Community Pool",
  "priority": "normal"
}

### Get All Documents
GET http://localhost:8080/api/documents/community/1

### Get All Tickets
GET http://localhost:8080/api/tickets/community/1

### Get Open Tickets
GET http://localhost:8080/api/tickets/community/1/open
```

**How to use:**
1. Open `test.http` in IntelliJ
2. Click the play button (▶) next to each request
3. View the response in the right panel

---

### Method 3: Using Postman

1. Open Postman
2. Create a new POST request
3. URL: `http://localhost:8080/api/chat`
4. Headers:
   - `Content-Type: application/json`
5. Body (raw JSON):
```json
{
  "message": "What are the pool hours?",
  "communityId": 1
}
```
6. Click Send

---

## Troubleshooting

### Issue: Connection refused (localhost:8080)
**Solution**: Make sure the app is running with `mvn spring-boot:run`

### Issue: Connection refused (localhost:5432)
**Solution**: Make sure Docker is running with `docker-compose up -d`

### Issue: "No explicit mapping for /error"
**Solution**: You're likely using GET instead of POST. Ensure you're using `POST` for `/api/chat`

### Issue: API Key errors
**Solution**: 
1. Check that your API keys are set in `application.yml` or environment variables:
   ```bash
   echo $ANTHROPIC_API_KEY
   echo $OPENAI_API_KEY
   ```
2. If empty, set them:
   ```bash
   export ANTHROPIC_API_KEY=your-key-here
   export OPENAI_API_KEY=your-key-here
   ```
3. Restart the application

### Issue: Database connection error
**Solution**:
```bash
# Stop and remove old containers
docker-compose down -v

# Restart
docker-compose up -d

# Check logs
docker logs hoa-postgres
```

---

## Expected Behavior

### First Chat (No Documents)
When you first chat without uploading documents, you should get a response like:
```
I don't have any relevant documents in my knowledge base to answer your question about pool hours. Please contact the community manager or try uploading relevant documents first.
```

### After Uploading Documents
After uploading CC&Rs or other documents, the assistant will:
1. Extract and process the document
2. Create vector embeddings
3. Store chunks in the database
4. Use this context to answer questions

---

## Sample Test Workflow

```bash
# 1. Start the app (if not already running)
mvn spring-boot:run

# 2. In a new terminal, upload a document
curl -X POST http://localhost:8080/api/documents/upload \
  -F "file=@/path/to/your/pdf.pdf" \
  -F "communityId=1" \
  -F "documentType=CC&Rs"

# 3. Wait a moment for processing, then ask a question
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What are the rules about parking?",
    "communityId": 1
  }'

# 4. Create a maintenance ticket
curl -X POST http://localhost:8080/api/tickets \
  -H "Content-Type: application/json" \
  -d '{
    "communityId": 1,
    "ticketType": "maintenance",
    "description": "Broken gate lock",
    "location": "Main Entrance",
    "priority": "high"
  }'
```

---

## API Response Examples

### Successful Chat Response
```json
{
  "response": "Based on the community guidelines, the pool hours are from 8 AM to 8 PM during summer months...",
  "communityId": 1,
  "sessionId": "session-123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Error Response
```json
{
  "error": "API key not configured. Please check ANTHROPIC_API_KEY environment variable.",
  "status": 500,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## Next Steps

1. **Create Sample Data**: Add sample documents to test the RAG functionality
2. **Frontend Development**: Build a React/Vue frontend for better UX
3. **Test Different Question Types**: Try questions that require context from documents
4. **Test Ticket Workflow**: Create tickets and verify they appear in the database

Good luck! 🚀

