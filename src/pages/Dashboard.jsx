// src/pages/Dashboard.jsx
import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

const Dashboard = () => {
	const [user, setUser] = useState(null);

	useEffect(() => {
		const getUser = async () => {
			const { data: { user } } = await supabase.auth.getUser();
			if (user) {
				setUser(user);
			}
		};

		getUser();
	}, []);

	const handleSignOut = async () => {
		await supabase.auth.signOut();
	};

	return (
		<div className="dashboard-container">
			<header>
				<h1>Dashboard</h1>
				<button onClick={handleSignOut}>Sign Out</button>
			</header>
			<main>
				{user && (
					<div>
						<p>Welcome, <strong>{user.email}</strong></p>
						<p>You've successfully logged in!</p>
					</div>
				)}
			</main>
		</div>
	);
};

export default Dashboard;

