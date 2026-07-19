# app/routes/documents.py
# Serves generated DOCX files for download
# Register in main.py:
#   from app.routes.documents import router as documents_router
#   app.include_router(documents_router)

import os
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(prefix="/documents", tags=["documents"])

# Same path as document_generator.py — two dirname() calls to reach project root
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
DOCUMENTS_DIR = os.path.join(_PROJECT_ROOT, "generated_documents")


@router.get("/download/{filename}")
async def download_document(filename: str):
    """
    Serves a generated DOCX file for download.

    Security: os.path.basename() strips any path traversal attempts
    (e.g. "../../etc/passwd" becomes "passwd" which won't exist in DOCUMENTS_DIR).

    Flutter calls this URL when the user taps the download chip in chat.
    URL pattern: GET /documents/download/Integration_by_Parts_20250619_143022.docx
    """
    # Strip path separators — never serve outside DOCUMENTS_DIR
    safe_name = os.path.basename(filename)

    # Only allow .docx and .pdf for safety
    if not (safe_name.endswith(".docx") or safe_name.endswith(".pdf")):
        raise HTTPException(status_code=400, detail="Invalid file type")

    filepath = os.path.join(DOCUMENTS_DIR, safe_name)

    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Document not found or has expired")

    # Detect MIME type
    media_type = (
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        if safe_name.endswith(".docx")
        else "application/pdf"
    )

    return FileResponse(
        path=filepath,
        filename=safe_name,
        media_type=media_type,
    )


@router.get("/list")
async def list_documents():
    """
    Returns all generated files (useful for debugging during dev).
    Remove or restrict this in production.
    """
    if not os.path.exists(DOCUMENTS_DIR):
        return {"files": []}

    files = [
        f for f in os.listdir(DOCUMENTS_DIR)
        if f.endswith(".docx") or f.endswith(".pdf")
    ]
    files.sort(reverse=True)   # newest first (timestamp in filename)
    return {"files": files, "count": len(files)}