"""Server-only Gemini setup. Module initialization makes no model request."""
import os;
import from pathlib { Path }
import from dotenv { load_dotenv }
import from jaclang.byllm.lib { Model }
with entry {
    load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env", override=False);
    if os.getenv("GEMINI_API_KEY") {
        os.environ["GOOGLE_API_KEY"] = os.environ["GEMINI_API_KEY"];
    }
}
glob language_model: Model = Model(model_name=os.getenv("GEMINI_MODEL", "gemini/gemini-3.8-flash"));
