// Fixtures that MUST NOT trigger. If a rule fires here it is too broad.
import jwt from "jsonwebtoken";

const publicUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

async function chat(req: any) {
  return openai.chat.completions.create({ model: "gpt-4", max_tokens: 500, messages: [] });
}

async function pay(req: any) {
  const item = await catalogue.find(req.body.itemId);
  return stripe.paymentIntents.create({ amount: item.priceCents, currency: "usd" });
}

async function save(req: any) {
  return User.update({ name: req.body.name, bio: req.body.bio });
}

const el = document.getElementById("x")!;
el.innerHTML = "<b>static markup</b>";

const claims = jwt.verify(token, process.env.JWT_SECRET!);
const event = stripe.webhooks.constructEvent(req.rawBody, sig, secret);

app.use(cors({ origin: ["https://app.example.com"], credentials: true }));
