import React from 'react';

function SearchBar({ searchTerm, onInputChange, onSubmit }) {
  return (
    <div className="flex justify-center mb-8">
      <form className="flex w-full max-w-md" onSubmit={onSubmit}>
        <input
          className="w-full px-4 py-2 leading-tight text-gray-700 bg-white border rounded-lg appearance-none focus:outline-none focus:shadow-outline"
          type="text"
          placeholder="Search"
          value={searchTerm}
          onChange={onInputChange}
        />
      </form>
    </div>
  );
}

export default SearchBar;
