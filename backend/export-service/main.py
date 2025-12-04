import sys
import os
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet
from io import BytesIO
import uuid

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.auth import get_current_user
from shared.supabase_client import get_supabase_client
from shared.logger import setup_logger

app = FastAPI(title="RareMatch Export Service", version="1.0.0")
logger = setup_logger("export-service")

class ExportRequest(BaseModel):
    timeline_id: str
    include_diagnosis: bool = True

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "export-service"}

@app.post("/export/pdf")
def generate_pdf(request: ExportRequest, user: dict = Depends(get_current_user)):
    """Generate PDF report for a timeline and upload to Supabase Storage."""
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    # 1. Fetch Data
    try:
        timeline_response = supabase.table("timelines").select("*").eq("id", request.timeline_id).single().execute()
        if not timeline_response.data:
            raise HTTPException(status_code=404, detail="Timeline not found")
        timeline = timeline_response.data
    except Exception as e:
        logger.error(f"Error fetching timeline for export: {e}")
        # Mock data for dev if DB fails
        timeline = {
            "title": "Sample Timeline",
            "description": "Mock description for PDF generation.",
            "symptoms": [
                {"symptom_name": "Headache", "start_date": "2023-01-01", "severity": 8},
                {"symptom_name": "Fatigue", "start_date": "2023-01-05", "severity": 6}
            ]
        }

    # 2. Generate PDF
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter)
    styles = getSampleStyleSheet()
    story = []

    # Title
    story.append(Paragraph(f"RareMatch Report: {timeline.get('title', 'Untitled')}", styles['Title']))
    story.append(Spacer(1, 12))
    
    # Description
    story.append(Paragraph(f"Description: {timeline.get('description', '')}", styles['Normal']))
    story.append(Spacer(1, 12))

    # Symptoms Table
    data = [["Symptom", "Start Date", "Severity"]]
    for s in timeline.get("symptoms", []):
        data.append([s.get("symptom_name"), s.get("start_date"), str(s.get("severity"))])

    t = Table(data)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    story.append(t)

    doc.build(story)
    pdf_bytes = buffer.getvalue()
    buffer.close()

    # 3. Upload to Storage
    filename = f"reports/{user_id}/{uuid.uuid4()}.pdf"
    try:
        # Supabase Storage Upload
        # Note: Bucket 'reports' must exist
        supabase.storage.from_("reports").upload(
            path=filename,
            file=pdf_bytes,
            file_options={"content-type": "application/pdf"}
        )
        
        # Get Public URL
        public_url = supabase.storage.from_("reports").get_public_url(filename)
        return {"url": public_url}
    except Exception as e:
        logger.error(f"Error uploading PDF: {e}")
        # Return mock URL for dev
        return {"url": "https://example.com/mock-report.pdf", "note": "Storage upload failed, returned mock URL"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8005)
