// Camada de acesso à API Femme.
// O backend passa a ser Node.js/Express, com a ligação à base de dados MySQL
// feita em JavaScript (ex.: driver mysql2) — o contrato da API mantém-se igual.
const API_BASE = "http://localhost:3000/api";

async function apiFetch(path, { method = "GET", body, auth = true } = {}) {
  const headers = { "Content-Type": "application/json" };
  const token = localStorage.getItem("femme_token");
  if (auth && token) headers["Authorization"] = `Bearer ${token}`;

  const resp = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  let data = null;
  try { data = await resp.json(); } catch (e) { /* resposta sem corpo */ }

  if (!resp.ok) {
    throw new Error((data && data.erro) || `Erro ${resp.status}`);
  }
  return data;
}

const Sessao = {
  guardar(token, utilizador) {
    localStorage.setItem("femme_token", token);
    localStorage.setItem("femme_user", JSON.stringify(utilizador));
  },
  utilizador() {
    const raw = localStorage.getItem("femme_user");
    return raw ? JSON.parse(raw) : null;
  },
  token() { return localStorage.getItem("femme_token"); },
  terminar() {
    localStorage.removeItem("femme_token");
    localStorage.removeItem("femme_user");
  },
  exigirTipo(tipo, paginaLogin) {
    const user = Sessao.utilizador();
    if (!user || !Sessao.token() || user.tipo !== tipo) {
      window.location.href = paginaLogin;
    }
    return user;
  },
  // Exige apenas que exista sessão iniciada (qualquer tipo de utilizador).
  // Usado em páginas públicas que passam a só ficar visíveis depois de login (ex.: Descobrir).
  exigirLogin(paginaLogin) {
    const user = Sessao.utilizador();
    if (!user || !Sessao.token()) {
      const destino = encodeURIComponent(window.location.pathname + window.location.search);
      window.location.href = `${paginaLogin}?next=${destino}`;
      return null;
    }
    return user;
  },
};

// Envio de ficheiros (multipart/form-data) — usado, por exemplo, no upload dos
// documentos do profissional para aprovação do administrador.
async function apiUpload(path, formData) {
  const headers = {};
  const token = localStorage.getItem("femme_token");
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const resp = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers, // sem Content-Type: o browser define o boundary do multipart automaticamente
    body: formData,
  });

  let data = null;
  try { data = await resp.json(); } catch (e) { /* resposta sem corpo */ }

  if (!resp.ok) {
    throw new Error((data && data.erro) || `Erro ${resp.status}`);
  }
  return data;
}

function alertaErro(container, mensagem) {
  container.innerHTML = `<div class="alert alert-danger py-2">${mensagem}</div>`;
}
function alertaSucesso(container, mensagem) {
  container.innerHTML = `<div class="alert alert-success py-2">${mensagem}</div>`;
}
function formatarData(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString("pt-PT", { weekday: "short", day: "2-digit", month: "short" }) +
    " · " + d.toLocaleTimeString("pt-PT", { hour: "2-digit", minute: "2-digit" });
}
const ROTULOS_ESTADO = {
  pendente: "Pendente", confirmada: "Confirmada", recusada: "Recusada",
  cancelada: "Cancelada", concluida: "Concluída", aprovado: "Aprovado",
  rejeitado: "Rejeitado", publicada: "Publicada", ativo: "Ativa", desativado: "Desativada",
};
const CORES_BADGE = {
  pendente: "warning", confirmada: "success", recusada: "secondary",
  cancelada: "secondary", concluida: "primary", aprovado: "success",
  rejeitado: "secondary", publicada: "success", ativo: "success", desativado: "secondary",
};
function badgeEstado(estado) {
  return `<span class="badge text-bg-${CORES_BADGE[estado] || "secondary"}">${ROTULOS_ESTADO[estado] || estado}</span>`;
}
