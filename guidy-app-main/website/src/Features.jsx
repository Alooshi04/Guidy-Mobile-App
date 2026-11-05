import { useLang } from "./lang";

export default function Features() {
  const { t } = useLang();
  const f = t.features;
  return (
    <>
      <section className="page-head">
        <div className="wrap">
          <p className="eyebrow">{f.label}</p>
          <h1>{f.title}</h1>
          <p className="lead">{f.lead}</p>
        </div>
      </section>
      {f.groups.map((g) => (
        <section className="feature-group" key={g.title} data-reveal>
          <div className="wrap split">
            <h2>{g.title}</h2>
            <dl className="feature-list">
              {g.items.map(([title, body]) => (
                <div key={title}>
                  <dt>{title}</dt>
                  <dd>{body}</dd>
                </div>
              ))}
            </dl>
          </div>
        </section>
      ))}
      <section className="feature-group" id="data-sources" data-reveal>
        <div className="wrap split">
          <div>
            <h2>{t.sources.title}</h2>
            <p className="fine">{t.sources.lead}</p>
          </div>
          <dl className="feature-list">
            {t.sources.items.map(([name, body, href]) => (
              <div key={name}>
                <dt><a href={href} target="_blank" rel="noopener">{name}</a></dt>
                <dd>{body}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>
    </>
  );
}
