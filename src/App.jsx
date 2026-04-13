import { Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import Host from './pages/Host'
import Play from './pages/Play'
import Create from './pages/Create'

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/host" element={<Host />} />
      <Route path="/host/:sessionId" element={<Host />} />
      <Route path="/play/:code" element={<Play />} />
      <Route path="/create" element={<Create />} />
    </Routes>
  )
}
