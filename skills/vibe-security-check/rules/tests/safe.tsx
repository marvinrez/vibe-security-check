// JSX fixtures that MUST NOT trigger.
import DOMPurify from "dompurify";

export function Static() {
  return <div dangerouslySetInnerHTML={{ __html: "<b>static markup</b>" }} />;
}

export function Comment({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />;
}

export async function Answer() {
  const completion = await openai.chat.completions.create({ model: "gpt-4", messages: [] });
  return <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(completion.choices[0].message.content) }} />;
}
