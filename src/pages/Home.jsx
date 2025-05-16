// src/pages/Home.jsx
import Auth from '../components/Auth';

const Home = () => {
	return (
		<div className="home-container">
			<header>
				<h1>Quiz App</h1>
				<p>Create and join interactive quizzes</p>
			</header>
			<main>
				<Auth />
			</main>
		</div>
	);
};

export default Home;

