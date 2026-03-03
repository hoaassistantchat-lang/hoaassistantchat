# HOA Assistant - Quick Start Guide for Windows

## Step-by-Step Setup Instructions

### Step 1: Download and Extract Project

1. Download the `hoa-assistant` folder from this conversation
2. Extract it to your desired location (e.g., `C:\Users\Nares\projects\hoa-assistant`)

### Step 2: Start PostgreSQL Database

1. Open Command Prompt or PowerShell
2. Navigate to project directory:
   ```
   cd C:\Users\Nares\projects\hoa-assistant
   ```
3. Start Docker containers:
   ```
   docker-compose up -d
   ```
4. Verify it's running:
   ```
   docker ps
   ```
   You should see `hoa-postgres` container running

### Step 3: Configure API Keys

You need two API keys:

**A. Get Anthropic API Key:**
1. Visit: https://console.anthropic.com/
2. Sign up or log in
3. Go to API Keys section
4. Create a new API key
5. Copy the key (starts with `sk-ant-...`)

**B. Get OpenAI API Key:**
1. Visit: https://platform.openai.com/
2. Sign up or log in
3. Go to API Keys section
4. Create a new API key
5. Copy the key (starts with `sk-...`)

**C. Add Keys to Project:**

Option 1 - Edit application.yml file:
1. Open `src\main\resources\application.yml` in any text editor
2. Find these lines:
   ```yaml
   anthropic:
     api-key: ${ANTHROPIC_API_KEY:your-api-key-here}
   ```
3. Replace `your-api-key-here` with your actual key:
   ```yaml
   anthropic:
     api-key: sk-ant-your-actual-key-here
   ```
4. Do the same for OpenAI key

Option 2 - Use Environment Variables (Recommended):
```
set ANTHROPIC_API_KEY=sk-ant-your-key-here
set OPENAI_API_KEY=sk-your-openai-key-here
```

### Step 4: Open Project in IntelliJ IDEA

1. Open IntelliJ IDEA
2. Click `File` → `Open`
3. Navigate to `hoa-assistant` folder
4. Click `OK`
5. IntelliJ will detect it's a Maven project and start downloading dependencies
6. Wait for the build to complete (bottom right corner shows progress)

### Step 5: Run the Application

**Option A - From IntelliJ:**
1. Navigate to `src/main/java/com/hoa/assistant/HoaAssistantApplication.java`
2. Right-click on the file
3. Click `Run 'HoaAssistantApplication'`

**Option B - From Command Line:**
```
mvn clean install
mvn spring-boot:run
```

### Step 6: Verify It's Working

1. Open a browser and go to: `http://localhost:8080/api/chat/health`
2. You should see: "Chat service is running"

### Step 7: Test the Chat API

Open a new Command Prompt and run:

```bash
curl -X POST http://localhost:8080/api/chat ^
  -H "Content-Type: application/json" ^
  -d "{\"message\": \"What are the office hours?\", \"communityId\": 1}"
```

You should get a response from the AI!

## Next Steps: Upload a Document

Create a sample PDF document about your HOA rules, then upload it:

```bash
curl -X POST http://localhost:8080/api/documents/upload ^
  -F "file=@C:\path\to\your\document.pdf" ^
  -F "communityId=1" ^
  -F "documentType=CC&Rs"
```

The system will:
1. Save the PDF
2. Extract text
3. Create embeddings
4. Store in vector database

Now when you ask questions, the AI will use your documents!

## Troubleshooting

### Problem: "Port 8080 already in use"
**Solution:** Another app is using port 8080. Either:
- Stop the other app
- Or change port in `application.yml`:
  ```yaml
  server:
    port: 8081
  ```

### Problem: "Cannot connect to database"
**Solution:** 
1. Make sure Docker Desktop is running
2. Check if PostgreSQL container is running:
   ```
   docker ps
   ```
3. If not running:
   ```
   docker-compose up -d
   ```

### Problem: "API key invalid"
**Solution:** 
1. Double-check your API keys
2. Make sure there are no extra spaces
3. Verify the keys are active in the API dashboards

### Problem: Maven build fails
**Solution:**
```
mvn clean install -U
```

## Testing the Full Workflow

### 1. Upload a sample HOA document (PDF)
### 2. Ask questions about the document
### 3. Create a ticket
### 4. Check ticket status

Example conversation:
```
You: "What are the pool rules?"
AI: "Based on the community documents... [citation from your PDF]"

You: "I need to report a broken pool light"
AI: "I can help you create a maintenance ticket..."
```

## Project Structure

```
hoa-assistant/
├── src/main/java/          # Java source code
├── src/main/resources/     # Configuration and prompts
├── docker-compose.yml      # Database setup
├── pom.xml                 # Maven dependencies
└── README.md               # Detailed documentation
```

## Important Files

- **Application Config**: `src/main/resources/application.yml`
- **System Prompt**: `src/main/resources/prompts/system-prompt.txt`
- **Main Class**: `src/main/java/com/hoa/assistant/HoaAssistantApplication.java`

## API Endpoints Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/chat` | POST | Send chat message |
| `/api/chat/health` | GET | Check service status |
| `/api/documents/upload` | POST | Upload PDF document |
| `/api/tickets` | POST | Create support ticket |
| `/api/tickets/community/{id}` | GET | List all tickets |

## Need Help?

1. Check the main README.md for detailed documentation
2. Review application logs in IntelliJ console
3. Check Docker logs: `docker logs hoa-postgres`

## Success Checklist

- ✅ Docker Desktop running
- ✅ PostgreSQL container running
- ✅ API keys configured
- ✅ Application running on port 8080
- ✅ Health check returns "Chat service is running"
- ✅ Chat endpoint responds to messages

You're all set! Start uploading documents and chatting with your HOA Assistant! 🚀
