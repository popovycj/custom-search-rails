import React, { useState, useEffect } from 'react';
import axios from 'axios';
import SearchBar from './SearchBar';
import SearchResults from './SearchResults';

function App() {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      const { data } = await axios.get(`/search.json?query=${searchTerm}`);
      setSearchResults(data);
    };

    fetchData();
  }, [searchTerm]);

  const handleInputChange = (event) => {
    setSearchTerm(event.target.value);
  };

  const handleSubmit = (event) => {
    event.preventDefault();
  };

  return (
    <div className="container px-4 py-8 mx-auto">
      <SearchBar searchTerm={searchTerm} onInputChange={handleInputChange} onSubmit={handleSubmit} />
      <SearchResults searchResults={searchResults} />
    </div>
  );
};

export default App;
