export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-indigo-50 to-blue-100 flex items-center justify-center p-8">
      <div className="bg-white rounded-2xl shadow-xl p-10 max-w-2xl w-full text-center">
        <h1 className="text-4xl font-bold text-indigo-700 mb-4">
          💰 Budgcoach Admin
        </h1>
        <p className="text-gray-500 text-lg mb-8">
          AI-driven personalized budget optimizer for Nepalese youth. <br />
          Combating <span className="font-semibold text-indigo-500">Spendception</span> — one transaction at a time.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-left">
          <div className="rounded-xl bg-indigo-50 p-4">
            <p className="text-xs text-indigo-400 uppercase font-semibold mb-1">ML Engine</p>
            <p className="text-sm text-gray-700">FastAPI + Random Forest + LSTM</p>
          </div>
          <div className="rounded-xl bg-green-50 p-4">
            <p className="text-xs text-green-400 uppercase font-semibold mb-1">Database</p>
            <p className="text-sm text-gray-700">Supabase (PostgreSQL + RLS)</p>
          </div>
          <div className="rounded-xl bg-amber-50 p-4">
            <p className="text-xs text-amber-400 uppercase font-semibold mb-1">OCR</p>
            <p className="text-sm text-gray-700">Tesseract — eSewa &amp; Khalti PDFs</p>
          </div>
        </div>
        <p className="mt-8 text-xs text-gray-400">
          Configure your <code className="bg-gray-100 px-1 rounded">.env.local</code> to connect to Supabase and the ML Engine.
        </p>
      </div>
    </main>
  );
}
