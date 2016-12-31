require "miga/tax_dist"

module QueryDatasetsHelper
  def aai_intax(aai, project_id, ds_miga)
    res = MiGA::TaxDist.aai_taxtest(aai, :intax)
    tax = ds_miga.metadata[:tax]
    tax = {} if tax.nil?
    phrases = []
    res.each do |k,v|
      o = k.to_s.unmiga_name + " belongs to the "
      if tax=={} or tax[v.first].nil?
        o += "same <b>#{MiGA::Taxonomy.LONG_RANKS[v.first]}</b> of " +
          link_to(ds_miga.name.unmiga_name,
            reference_dataset_path(project_id, ds_miga.name))
      else
        o += "<b>#{MiGA::Taxonomy.LONG_RANKS[v.first]}</b> " +
          "<em>#{tax[v.first].unmiga_name}</em>"
      end
      o += " (p-value: #{"%.2g" % v.second})"
      phrases << o
    end
    all = "<div class='text-muted small comment'><b>P-values:</b> " +
            MiGA::TaxDist.aai_pvalues(aai, :intax).map do |k,v|
              "<b>#{MiGA::Taxonomy.LONG_RANKS[k]} <em>#{tax[k]}</em></b> #{
                "%.3g" % v}"
            end.join(", ") + ".</div>"
    return (phrases.empty? ?
            "The dataset doesn't have any close relative in the database " +
              "that can be used to determine its taxonomy. #{all}" :
            "The dataset #{phrases.to_sentence}. #{all}".html_safe
      ).html_safe
  end

  def aai_novel(aai)
    res = MiGA::TaxDist.aai_taxtest(aai, :novel)
    thr = {most_likely:0.01, probably:0.1, possibly_even:0.5}
    phrases = []
    res.each do |k,v|
      next if [:d, :root].include? v.first
      rank = MiGA::Taxonomy.LONG_RANKS[v.first]
      phrases << "" + k.to_s.unmiga_name +
        " belongs to #{rank[0]=="o" ? "an" : "a"} <b>#{rank}</b> not " +
        "represented in the database (p-value: #{"%.2g" % v.second}), " +
        "highest taxonomic rank with p-value &le; #{thr[k]}"
    end
    all = "<div class='text-muted small comment'><b>P-values:</b> " +
            MiGA::TaxDist.aai_pvalues(aai, :novel).map do |k,v|
              "<b>#{MiGA::Taxonomy.LONG_RANKS[k]}</b> #{"%.3g" % v}"
            end.join(", ") + ".</div>"
    conn = ". It "
    return (phrases.empty? ?
          "The dataset doesn't have any determinable degree of novelty with " +
            "respect to the database. #{all}" :
          "The dataset #{phrases.to_sentence(words_connector:conn,
            two_words_connector:conn, last_word_connector: conn)}. #{all}"
      ).html_safe
  end
end
