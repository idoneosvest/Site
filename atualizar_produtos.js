const fs = require('fs');
const path = require('path');

const produtosDir = path.join(__dirname, 'produtos');
const outputFile = path.join(__dirname, 'produtos_dados.js');

let produtosExistentes = {};

if (fs.existsSync(outputFile)) {
  const content = fs.readFileSync(outputFile, 'utf8');
  const match = content.match(/const listaProdutos = (\[[\s\S]*\]);/);
  if (match) {
    try {
      const json = JSON.parse(match[1]);
      json.forEach(p => {
        produtosExistentes[p.imagem] = p;
      });
    } catch (e) {}
  }
}

try {
  const files = fs.readdirSync(produtosDir).filter(file => {
    return ['.jpg', '.jpeg', '.png', '.gif', '.jfif', '.webp'].includes(path.extname(file).toLowerCase());
  });

  const newList = files.map(file => {
    if (produtosExistentes[file]) {
      return produtosExistentes[file];
    } else {
      const defaultName = file.split('.')[0]
        .replace('Modelo', 'Produto ')
        .replace('modelo', 'Produto ')
        .trim();
      return {
        imagem: file,
        preco: 0.00,
        nome: defaultName
      };
    }
  });

  const finalContent = `const listaProdutos = ${JSON.stringify(newList, null, 2)};`;
  fs.writeFileSync(outputFile, finalContent);
  console.log('produtos_dados.js atualizado! Novos itens com preco R$ 0,00 e nome padrao.');
} catch (err) {
  console.error('Erro ao atualizar produtos_dados.js:', err);
}