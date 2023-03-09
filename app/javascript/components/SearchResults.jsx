import React from 'react'

function SearchResults({ searchResults }) {
  return (
    <div className="flex flex-col gap-4">
      {searchResults.map((result, index) => (
        <div key={index} className="p-4 bg-white rounded-lg shadow">
          <h2 className="mb-2 text-lg font-semibold">{result["Name"]}</h2>
          <p className="text-gray-700"><strong>Type:</strong> {result["Type"]}</p>
          <p className="text-gray-700"><strong>Designed by:</strong> {result["Designed by"]}</p>
        </div>
      ))}
    </div>
  );
}

export default SearchResults;
