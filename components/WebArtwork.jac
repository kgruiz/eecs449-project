"""Decorative web branding; no conversation state or controls."""

def:pub BrandMark -> JsxElement {
    <svg className="brand-mark" viewBox="0 0 48 48" aria-hidden="true" focusable="false">
        <rect width="48" height="48" rx="15" fill="currentColor"/>
        <path d="M12 22v4m6-10v16m6-20v24m6-18v12m6-9v6" stroke="white" strokeWidth="2.6" strokeLinecap="round"/>
    </svg>
}

def:pub PipCompanion -> JsxElement {
    <svg className="pip-companion" viewBox="0 0 180 180" aria-hidden="true" focusable="false">
        <ellipse cx="90" cy="158" rx="49" ry="7" fill="#172443" opacity="0.07"/>
        <path d="M40 49 70 25 115 26 146 53 156 100 131 139 84 151 45 129 24 89Z" fill="#3057eb"/>
        <path d="m40 49 30-24-9 52-37 12Z" fill="#5479ff"/>
        <path d="m70 25 45 1 31 27-36 1Z" fill="#1e43d6"/>
        <path d="m115 26 31 27 10 47-28-13Z" fill="#1638b5"/>
        <path d="m24 89 21 40 39 22-23-40Z" fill="#1c40ce"/>
        <path d="m84 151 47-12 25-39-28 17Z" fill="#1738aa"/>
        <path d="m33 70-16-9 8 28m119-17 20-11-9 35" fill="#2446cb"/>
        <ellipse cx="69" cy="87" rx="10" ry="13" fill="#fffdf7"/>
        <ellipse cx="114" cy="87" rx="10" ry="13" fill="#fffdf7"/>
        <circle cx="72" cy="89" r="4.5" fill="#172443"/>
        <circle cx="111" cy="89" r="4.5" fill="#172443"/>
        <ellipse cx="50" cy="106" rx="7" ry="4" fill="#f6aaa0"/>
        <ellipse cx="131" cy="106" rx="7" ry="4" fill="#f6aaa0"/>
        <path d="M80 112q11 14 22 0" fill="none" stroke="#fffdf7" strokeWidth="4" strokeLinecap="round"/>
        <path d="m148 26 3 8 8 3-8 3-3 8-3-8-8-3 8-3Z" fill="#ef8a72"/>
    </svg>
}
