// Fixtures that MUST trigger. Each line is annotated with the rule it exercises.
import jwt from "jsonwebtoken";

// service-role-key-outside-server
const admin = process.env.SUPABASE_SERVICE_ROLE_KEY;

// public-prefixed-secret
const leaked = process.env.NEXT_PUBLIC_STRIPE_SECRET_KEY;

// cost-parameter-from-client
async function chat(req: any) {
  return openai.chat.completions.create({ model: req.body.model, messages: [] });
}
async function chat2(req: any) {
  return openai.chat.completions.create({ model: "gpt-4", max_tokens: req.body.max_tokens });
}

// price-from-client
async function pay(req: any) {
  return stripe.paymentIntents.create({ amount: req.body.amount, currency: "usd" });
}

// mass-assignment-from-body
async function save(req: any) {
  return User.update(req.body);
}

// dangerous-html-with-variable
const el = document.getElementById("x")!;
el.innerHTML = userComment;

// tls-verification-disabled
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

// webhook-signature-against-parsed-body
const event = stripe.webhooks.constructEvent(req.body, sig, secret);

// jwt-decoded-without-verification
const claims = jwt.decode(token);

// permissive-cors-with-credentials
app.use(cors({ origin: "*", credentials: true }));
