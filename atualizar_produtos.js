const fs = require('fs');
const path = require('path');

const produtosDir = path.join(__dirname, 'produtos');
const outputFile = path.join(__dirname, 'produtos_dados.js');

try {
  const files = fs.readdirSync(produtosDir).filter(file => {
    return ['.jpg', '.jpeg', '.png', '.gif', '.jfif', '.webp'].includes(path.extname(file).toLowerCase());
  });

  const content = `const listaProdutos = ${JSON.stringify(files, null, 2)};`;
  fs.writeFileSync(outputFile, content);
  console.log('produtos_dados.js atualizado com sucesso!');
} catch (err) {
  console.error('Erro ao atualizar produtos_dados.js:', err);
}