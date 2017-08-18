/*
Language: GraphQL
Author: David Peek <mail@dpeek.com>
Description: GraphQL schema, query, mutation and subscription
*/

export default function graphql(hljs) {
  return {
    aliases: ['gql', 'graphql'],
    keywords: {
      keyword: 'query mutation subscription type interface union scalar fragment enum on ...',
      literal: 'true false null'
    },
    contains: [
      hljs.HASH_COMMENT_MODE,
      hljs.QUOTE_STRING_MODE,
      hljs.NUMBER_MODE,
      { className: 'type',
        begin: '[^\\w][A-Z][a-z]', end: '\\W',
        excludeEnd: true
      },
      { className: 'literal',
        begin: '[^\\w][A-Z][A-Z]', end: '\\W',
        excludeEnd: true
      },
      { className: 'variable',
        begin: '\\$', end: '\\W',
        excludeEnd: true
      },
      {
        className: 'keyword',
        begin: '[.]{2}', end: '\\.',
      },
      {
        className: 'meta',
        begin: '@', end: '\\W',
        excludeEnd: true
      }
    ]
  }
}
