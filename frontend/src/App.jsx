import { useEffect, useState } from 'react'

const apiBase = import.meta.env.VITE_API_BASE_URL || '/api'

export default function App() {
  const [todos, setTodos] = useState([])
  const [title, setTitle] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  async function loadTodos() {
    try {
      setError('')
      const response = await fetch(`${apiBase}/todos`)
      if (!response.ok) {
        throw new Error(`Failed to load todos (${response.status})`)
      }
      const data = await response.json()
      setTodos(data)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadTodos()
  }, [])

  async function submitTodo(event) {
    event.preventDefault()
    if (!title.trim()) {
      return
    }

    const response = await fetch(`${apiBase}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: title.trim() })
    })

    if (!response.ok) {
      setError(`Failed to save todo (${response.status})`)
      return
    }

    setTitle('')
    await loadTodos()
  }

  return (
    <main className="app-shell">
      <section className="card">
        <h1>Demo E2E Stack</h1>
        <p>.NET API + React + Postgres + Helm + Argo CD</p>

        <form onSubmit={submitTodo} className="form-row">
          <input
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Add a todo"
            aria-label="Todo title"
          />
          <button type="submit">Add</button>
        </form>

        {loading ? <p>Loading...</p> : null}
        {error ? <p className="error">{error}</p> : null}

        <ul>
          {todos.map((todo) => (
            <li key={todo.id}>
              <span>{todo.title}</span>
              <small>{new Date(todo.createdAt).toLocaleString()}</small>
            </li>
          ))}
        </ul>
      </section>
    </main>
  )
}
