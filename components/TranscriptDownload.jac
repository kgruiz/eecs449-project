"""Download the currently displayed transcript locally, without a server call."""
import from ..core.models { SessionView }
import from ..core.transcript { format_transcript }

def:pub TranscriptDownload(session: SessionView) -> JsxElement {
    has error: str = "";

    def downloadTranscript() -> None {
        browser: any = window;
        link: any = browser.document.createElement("a");
        object_url: str = "";
        error = "";
        try {
            blob = new(browser.Blob, [format_transcript(session)], {"type": "text/plain;charset=utf-8"});
            object_url = browser.URL.createObjectURL(blob);
            link.href = object_url;
            link.setAttribute("download", "language-assistant-" + session.id + ".txt");
            browser.document.body.appendChild(link);
            link.click();
        } except Exception {
            error = "Could not download the transcript. You can still select and copy the text below.";
        } finally {
            link.remove();
            if object_url {
                # Let the browser begin reading the file before releasing its URL.
                browser.setTimeout(lambda { browser.URL.revokeObjectURL(object_url); }, 1000);
            }
        }
    }

    <div className="transcript-download">
        <button type="button" className="download-button" disabled={len(session.turns) == 0} onClick={downloadTranscript}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">
                <path d="M12 3v12m-5-5 5 5 5-5M4 15v6h16v-6"/>
            </svg>
            Download transcript (.txt)
        </button>
        {error and <p className="error-banner" role="alert">{error}</p>}
    </div>
}
