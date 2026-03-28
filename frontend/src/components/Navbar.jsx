import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext.jsx';
import { useCart } from '../context/CartContext.jsx';

const Navbar = () => {
  const { user, logout } = useAuth();
  const { getCartCount } = useCart();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  const styles = {
    navbar: {
      backgroundColor: '#2c3e50',
      color: 'white',
      padding: '15px 20px',
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      boxShadow: '0 2px 4px rgba(0,0,0,0.1)'
    },
    logo: {
      fontSize: '24px',
      fontWeight: 'bold',
      color: 'white',
      textDecoration: 'none'
    },
    navLinks: {
      display: 'flex',
      gap: '20px',
      alignItems: 'center'
    },
    link: {
      color: 'white',
      textDecoration: 'none',
      padding: '8px 12px',
      borderRadius: '4px',
      transition: 'background-color 0.2s'
    },
    cartBadge: {
      backgroundColor: '#e74c3c',
      color: 'white',
      borderRadius: '50%',
      padding: '2px 8px',
      fontSize: '12px',
      marginLeft: '5px'
    },
    button: {
      backgroundColor: '#e74c3c',
      color: 'white',
      border: 'none',
      padding: '8px 16px',
      borderRadius: '4px',
      cursor: 'pointer'
    }
  };

  return (
    <nav style={styles.navbar}>
      <Link to="/" style={styles.logo}>E-Commerce Store</Link>
      <div style={styles.navLinks}>
        <Link to="/" style={styles.link}>Products</Link>
        <Link to="/cart" style={styles.link}>
          Cart
          {getCartCount() > 0 && (
            <span style={styles.cartBadge}>{getCartCount()}</span>
          )}
        </Link>
        {user ? (
          <>
            <Link to="/orders" style={styles.link}>My Orders</Link>
            <span>Welcome, {user.username}</span>
            <button onClick={handleLogout} style={styles.button}>Logout</button>
          </>
        ) : (
          <>
            <Link to="/login" style={styles.link}>Login</Link>
            <Link to="/register" style={{ ...styles.link, backgroundColor: '#27ae60' }}>Register</Link>
          </>
        )}
      </div>
    </nav>
  );
};

export default Navbar;
