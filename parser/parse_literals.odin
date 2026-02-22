package main

// Literal types:
//   Function   - `{ return x }`, `{ f(x) }`   Delimeter ;
//   Compound   - `{ x, y, z }, `{ f(x) }`     Delimeter ,
//   Designated - `{ x: a, b: c }`             Delimeter :

// Encounter brace
//   Parse expression
//     Is identifier list?
//       Parse until every identifier ends
//         Check token
//         ,   - Compound
//         }   - Compound
//         :=  - Function
//         =   - Function
//     Is a call?
//       Check delimeter
//       :   - Designated
//       ,   - Compound
//       ;   - Function
//       N/A - Compound/Function <- fuck, oh well
//     Is a valid expression?
//       Check Delimeter
//       :   - Designated
//       ,   - Compound
//       N/A - Compound
//     Else 
//       Function or error
